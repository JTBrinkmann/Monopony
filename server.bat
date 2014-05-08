@echo off
cd .\server
:start
echo Server starting...
echo press Ctrl+C to stop the server
echo press then either Y and Enter to close or again Ctrl+C to restart the server
echo.
echo.
node.exe server_v2.js

echo.
echo Server stopped.
pause
echo.
echo.
echo ===============================================================================================
echo ===============================================================================================
echo.
echo.
goto start