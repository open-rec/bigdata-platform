import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ENTRYPOINT = Path(__file__).resolve().parents[1] / 'entrypoint.sh'


class EntrypointTest(unittest.TestCase):
    def test_local_model_path_and_public_model_name_are_separate(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            model = root / 'local model'
            model.mkdir()
            (model / 'config.json').write_text('{}')
            executable = root / 'vllm'
            executable.write_text('#!/usr/bin/env python3\nimport json,sys\nprint(json.dumps(sys.argv[1:]))\n')
            executable.chmod(0o755)
            env = dict(os.environ, PATH=str(root) + ':' + os.environ['PATH'],
                       VLLM_MODEL_NAME='Qwen/Qwen3-Embedding-0.6B', VLLM_MODEL_PATH=str(model),
                       VLLM_API_KEY='test key', VLLM_POOLER_CONFIG='{"pooling_type":"LAST"}')
            result = subprocess.run(['bash', str(ENTRYPOINT), '--enforce-eager'],
                                    env=env, capture_output=True, text=True, check=True)
            args = json.loads(result.stdout)
            self.assertEqual(args[:2], ['serve', str(model)])
            self.assertEqual(args[args.index('--served-model-name') + 1], env['VLLM_MODEL_NAME'])
            self.assertEqual(args[args.index('--api-key') + 1], 'test key')
            self.assertEqual(args[args.index('--pooler-config') + 1], env['VLLM_POOLER_CONFIG'])
            self.assertEqual(args[args.index('--runner') + 1], 'pooling')
            self.assertNotIn('--task', args)
            self.assertEqual(args[-1], '--enforce-eager')

    def test_missing_local_model_fails_before_loading(self):
        result = subprocess.run(['bash', str(ENTRYPOINT)], capture_output=True, text=True,
                                env=dict(os.environ, VLLM_MODEL_PATH='/nonexistent-openrec-model'))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Model not found', result.stderr)
