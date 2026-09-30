import base64
import unittest

from tool.summarize_build_log import summarize_build_log


class BuildLogTest(unittest.TestCase):
    def test_keeps_first_cause_ahead_of_gradle_and_msbuild_wrappers(self):
        log = '\n'.join([
            *['compiling dependencies'] * 1000,
            'Error: failed to build native assets',
            'Caused by: missing compiler',
            *['stack frame'] * 1000,
            'BUILD FAILED',
            'error MSB8066: custom build exited with code 1',
        ])
        result = summarize_build_log(log)
        self.assertIn('Caused by: missing compiler', result)
        self.assertIn('error MSB8066:', result)
        self.assertLessEqual(len(result.splitlines()), 61)

    def test_redacts_secret_and_flutter_encoded_define(self):
        key = 'test-secret-private-key'
        define = base64.b64encode(f'VPN_RSA_PRIVATE_KEY_B64={key}'.encode()).decode()
        result = summarize_build_log(f'Error: {key}\ncommand --DartDefines={define}', key)
        self.assertNotIn(key, result)
        self.assertNotIn(define, result)
        self.assertEqual(result.count('[REDACTED]'), 2)

    def test_bounds_unrecognized_output_and_removes_terminal_colors(self):
        log = '\n'.join(['noise'] * 1000 + ['\x1b[31mfinal message\x1b[0m'])
        result = summarize_build_log(log)
        self.assertEqual(len(result.splitlines()), 60)
        self.assertTrue(result.endswith('final message'))
        self.assertNotIn('\x1b', result)

    def test_bounds_long_lines_and_repeated_errors(self):
        result = summarize_build_log(('Error: ' + 'x' * 10000 + '\n') * 1000)
        self.assertLessEqual(len(result.splitlines()), 61)
        self.assertTrue(all(len(line) <= 500 for line in result.splitlines()))


if __name__ == '__main__':
    unittest.main()
