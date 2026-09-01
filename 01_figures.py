#standard figures require DML Identification output with tipping_point = 0
#for total farm, total nonfarm, and fertilizer utilization
#Figure 4 also requires both core outcomes with tipping_point = 1

import subprocess
import sys
from pathlib import Path

root        = Path(__file__).resolve().parent
figures_dir = root / "Python Code" / "Pthon Figures Scripts"

scripts = [
    "DML Figure 2.py",
    "DML Figure 3.py",
    "DML Figure 4.py",
    "DML Figure 5.py",
    "DML Figure 6.py",
    "DML Figure Benchmark.py"
]

for script in scripts:
    path = figures_dir / script
    print(f"Running {script}...")
    result = subprocess.run([sys.executable, str(path)], check=True)

print("All figures complete.")
