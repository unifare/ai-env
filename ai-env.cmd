@echo off
rem ==============================================================================
rem ai-env.cmd - AI API Key Manager CMD Wrapper
rem ==============================================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ai-env.ps1" %*
