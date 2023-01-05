:: Builds the createDigiBatch.exe executable.
:: Runs in CMD window
:: Ruby must be installed, and RUBY_HOME must point to the directory where Ruby is installed, e.g. C:\Ruby27-x64

if "%RUBY_HOME%" == "" goto Usage

copy createDigiBatch.rb "%RUBY_HOME%\bin"
%RUBY_HOME:~,2%
cd "%RUBY_HOME%\bin"
ocra createDigiBatch.rb --dll ruby_builtin_dlls\libssp-0.dll --dll ruby_builtin_dlls\libgmp-10.dll
goto :EOF

:Usage
echo Ruby must be installed.
echo RUBY_HOME must point to the directory where Ruby is installed, e.g. C:\Ruby27-x64
