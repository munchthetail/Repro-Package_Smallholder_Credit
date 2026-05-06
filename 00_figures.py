import subprocess
import sys
from pathlib import Path

root        = Path(__file__).resolve().parent
figures_dir = root / "Python Code" / "Pthon Figures Scripts"

scripts = [
    "DML Figure A1.py",
    "DML Figure A2.py",
    "DML Figure A3.py",
]

for script in scripts:
    path = figures_dir / script
    print(f"Running {script}...")
    result = subprocess.run([sys.executable, str(path)], check=True)

print("All figures complete.")
