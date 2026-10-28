"""Generate the Verso user guide, including its checked examples and Run resources."""
import argparse
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser()
parser.add_argument('--output', default='_out/guide', help='Manual output directory')
args = parser.parse_args()
subprocess.run(['lake', 'exe', 'verso-run-guide', '--output', args.output,
                '--depth', '1', '--with-html-single'], cwd=root, check=True)
print(f'User guide: {root / args.output / "html-multi"}')
