# Ruby Development Kit (DevKit) is not installed.

The build of the `racc` gem is failing because the Ruby Development Kit (DevKit) is not installed. The DevKit is required to build native extensions for some gems on Windows.

Please follow these steps to install the DevKit:

1.  **Download the DevKit:**
    Go to the [RubyInstaller for Windows](https://rubyinstaller.org/downloads/) website and download the DevKit that corresponds to your Ruby installation (Ruby 2.6.x).

2.  **Extract the DevKit:**
    Extract the downloaded file to a permanent location, for example `C:\RubyDevKit`.

3.  **Initialize the DevKit:**
    Open a command prompt, navigate to the directory where you extracted the DevKit, and run the following commands:

    ```bash
    cd C:\RubyDevKit
    ruby dk.rb init
    ruby dk.rb install
    ```

4.  **Verify the installation:**
    After the installation is complete, you can verify it by running `gem install racc --platform=ruby`. If the gem is installed successfully, you can then run `bundle install` again in your project directory.
