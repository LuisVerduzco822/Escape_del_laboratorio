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
