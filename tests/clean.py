import sys
import os.path
import glob

os.chdir(os.path.dirname(sys.argv[0]))
for fn in  glob.glob('tmp_*.png') + glob.glob('tmp_*.pdf'):
    os.remove(fn)
