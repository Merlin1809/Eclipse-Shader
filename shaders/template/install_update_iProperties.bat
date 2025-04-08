@echo off
python -m pip install --upgrade git+https://github.com/MikiP98/iProperties.git
echo[
if %errorlevel% neq 0 (
    echo Installation/update failed!
    exit /b %errorlevel%
)
echo Installation/update successful!
echo[
pause
