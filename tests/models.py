"""Cache management and download guard tests; no model downloads required."""
import importlib.util
from pathlib import Path
import tempfile
import types
import sys
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('manager', Path(__file__).resolve().parents[1]/'source/model_manager.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class Models(unittest.TestCase):
    def test_invalid_repo_and_symlink(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            for value in ['../secret', '/tmp/model', 'org/../model', 'org/model/extra', 'org/x y']:
                with self.assertRaises(ValueError): m.repo_path(root, value)
            (root/'cache').mkdir()
            (root/'cache/hub').symlink_to(root)
            with self.assertRaises(ValueError): m.repo_path(root, 'org/model')

    def test_download_pins_revision_and_space_guard(self):
        with tempfile.TemporaryDirectory() as d:
            calls = []
            info = types.SimpleNamespace(sha='abc123',siblings=[types.SimpleNamespace(size=1024)])
            fake = types.SimpleNamespace(HfApi=lambda:types.SimpleNamespace(model_info=lambda *a,**k:info),snapshot_download=lambda *a,**k:calls.append((a,k)))
            with patch.dict(sys.modules, huggingface_hub=fake), patch.object(m, 'emit'):
                with patch.object(m.shutil,'disk_usage',return_value=types.SimpleNamespace(free=0)):
                    with self.assertRaises(RuntimeError): m.download(Path(d),'org/model')
                self.assertFalse(calls)
                m.download(Path(d),'org/model')
                self.assertEqual(calls[0][1]['revision'],'abc123')
                self.assertFalse(calls[0][1]['token'])

    def test_remove_to_trash_preserves_other_models(self):
        with tempfile.TemporaryDirectory() as d, tempfile.TemporaryDirectory() as home:
            root = Path(d)
            repo = m.repo_path(root,'org/model'); repo.mkdir(parents=True)
            (repo/'blobs').mkdir()
            shared = root/'cache/hub/blobs/shared'
            shared.parent.mkdir(); shared.write_text('weights')
            (repo/'blobs/weight').symlink_to('../../blobs/shared')
            other = m.repo_path(root,'org/other'); other.mkdir()
            with patch.object(m.Path,'home',return_value=Path(home)), patch.object(m,'emit'):
                m.remove(root,'org/model')
            self.assertFalse(repo.exists())
            self.assertTrue(other.exists())
            recovered = next((Path(home)/'.Trash').glob('*/blobs/weight'))
            self.assertFalse(recovered.is_symlink())
            self.assertEqual(recovered.read_text(),'weights')
            self.assertEqual(shared.read_text(),'weights')

if __name__ == '__main__': unittest.main()
