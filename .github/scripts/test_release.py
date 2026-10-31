"""Validate version resolution and rollback without creating real GitHub releases."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('release', Path(__file__).with_name('release.py'))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.previous = Path.cwd()
        os.chdir(self.directory.name)
        self.addCleanup(self.directory.cleanup)
        self.addCleanup(os.chdir, self.previous)

    def test_versions(self):
        self.assertEqual(release.parse('v1.2.3-rc.2+42')['code'], 42)
        self.assertTrue(release.parse('v1.2.3-alpha.1+1')['prerelease'])
        self.assertFalse(release.parse('v1.2.3+43')['prerelease'])
        for value in ('v1.0+1', 'v01.0.0+1', 'v1.0.0+0', 'v1.0.0',
                      'v1.0.0+2100000001', 'v1.0.0-alpha+1', 'v1.0.0+1\n'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                release.parse(value)

    def test_workflow_initializes_android_sdk_before_using_sdkmanager(self):
        workflow = Path(__file__).parents[1] / 'workflows' / 'release.yml'
        contents = workflow.read_text()
        self.assertLess(contents.index('android-actions/setup-android@v4'),
                        contents.index("sdkmanager 'platform-tools'"))

    def test_smoke_autoload_is_configured_once_after_other_autoloads_exist(self):
        original = '[autoload]\nAudioManager="*res://scripts/AudioManager.gd"\n'
        configured = release.configure_smoke_test(original)
        self.assertEqual(configured.count('ReleaseSmoke='), 1)
        self.assertIn('AudioManager=', configured)
        self.assertEqual(release.configure_smoke_test(configured), configured)

    def test_smoke_uses_normal_startup_and_checks_marker(self):
        with patch.object(release, 'run', return_value=subprocess.CompletedProcess(
                [], 0, 'RELEASE SMOKE: main scene loaded\n', '')) as run:
            release.smoke_test(Path('game.AppImage'))
        self.assertEqual(run.call_args.args, ('game.AppImage', '--appimage-extract-and-run',
                         '--headless', '--', '--release-smoke-test'))
        with patch.object(release, 'run', return_value=subprocess.CompletedProcess([], 0, '', '')):
            with self.assertRaisesRegex(ValueError, 'did not execute'):
                release.smoke_test(Path('game.AppImage'))

    def resolve_source(self, ref, sha):
        with patch.dict(os.environ, RELEASE_TAG='v1.0.0+2', GITHUB_SHA='branch-sha',
                        GITHUB_OUTPUT='output', GH_REPO='owner/repo'), \
                patch.object(release, 'optional', side_effect=[None, ref]), \
                patch.object(release, 'api', return_value={'object': {'type': 'commit', 'sha': sha}}), \
                patch.object(release, 'run', return_value=subprocess.CompletedProcess([], 0, '[[]]')):
            release.resolve()
        return json.loads(release.STATE.read_text())

    def test_new_tag_uses_selected_commit(self):
        state = self.resolve_source(None, None)
        self.assertEqual(state['sha'], 'branch-sha')
        self.assertFalse(state['existing_tag'])

    def test_existing_annotated_tag_uses_tagged_commit(self):
        state = self.resolve_source({'object': {'type': 'tag', 'sha': 'annotation'}}, 'tagged-commit')
        self.assertEqual(state['sha'], 'tagged-commit')
        self.assertTrue(state['existing_tag'])

    def test_published_versions_are_latest_including_preview_tags(self):
        for tag in ('v1.0.0-alpha.3+3', 'v1.0.0-beta.3+3', 'v1.0.0-rc.1+3', 'v1.0.0+3'):
            with self.subTest(tag=tag):
                state = {**release.parse(tag), 'sha': 'commit', 'existing_tag': True,
                         'assets': ['game.apk']}
                release.STATE.write_text(json.dumps(state))
                Path('dist').mkdir(exist_ok=True)
                Path('dist/game.apk').write_bytes(b'apk')
                with patch.object(release, 'optional', side_effect=[None,
                        {'object': {'type': 'commit', 'sha': 'commit'}}]), \
                        patch.object(release, 'api', side_effect=[{'id': 7},
                            [{'name': 'game.apk', 'size': 3, 'state': 'uploaded'}], {}]) as api, \
                        patch.object(release, 'run'):
                    release.publish()
                self.assertFalse(api.call_args_list[0].args[2]['prerelease'])
                self.assertEqual(api.call_args_list[-1].args,
                                 ('releases/7', 'PATCH', {'draft': False,
                                  'prerelease': False, 'make_latest': 'true'}))

    def test_failed_upload_removes_draft_and_new_tag(self):
        state = {**release.parse('v1.0.0+2'), 'sha': 'commit', 'existing_tag': False, 'assets': ['game.apk']}
        release.STATE.write_text(json.dumps(state))
        with patch.object(release, 'optional', side_effect=[None, None,
                {'id': 7, 'draft': True}, {'object': {'sha': 'commit'}}]), \
                patch.object(release, 'api', side_effect=[{}, {'id': 7}, None, None]) as api, \
                patch.object(release, 'run', side_effect=RuntimeError('upload failed')):
            with self.assertRaisesRegex(RuntimeError, 'upload failed'):
                release.publish()
        self.assertEqual(api.call_args_list[-2].args, ('releases/7', 'DELETE'))
        self.assertEqual(api.call_args_list[-1].args, ('git/refs/tags/v1.0.0%2B2', 'DELETE'))

    def test_cleanup_preserves_preexisting_tag(self):
        release.PUBLICATION.write_text(json.dumps({'tag': 'v1.0.0+2', 'sha': 'commit', 'created_tag': False}))
        with patch.object(release, 'optional', return_value={'id': 7, 'draft': True}), \
                patch.object(release, 'api') as api:
            release.cleanup()
        api.assert_called_once_with('releases/7', 'DELETE')

    def test_cleanup_preserves_published_release(self):
        release.PUBLICATION.write_text(json.dumps({'tag': 'v1.0.0+2', 'sha': 'commit', 'created_tag': True}))
        with patch.object(release, 'optional', return_value={'id': 7, 'draft': False}), \
                patch.object(release, 'api') as api:
            release.cleanup()
        api.assert_not_called()


if __name__ == '__main__':
    unittest.main()
