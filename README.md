# my-bash

`my-bash` is a customizable bash environment setup script that automates the installation of various tools and configurations to enhance your terminal experience.

## Features

- Installs essential command-line tools and utilities.
- Sets up a custom bash configuration.
- Installs and configures Oh My Posh for a beautiful prompt.
- Installs fzf for fuzzy finding.
- Installs zoxide for smarter directory navigation.
- Configures fastfetch for system information display.

## Prerequisites

- A Unix-like operating system (Linux, macOS, etc.)
- `git` installed on your system.
- A supported package manager (`apt`, `dnf`, `yum`, `pacman`, or `zypper`).

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/tonytech83/my-bash.git
   ```

2. Navigate to the project directory:

   ```bash
   cd my-bash
   ```

3. Run the installation script:

   ```bash
   ./install.sh
   ```

   The script will check for necessary tools, install dependencies, and set up your bash environment.

## Usage

After installation, restart your terminal to apply the changes. You should see a new prompt and have access to the installed tools.

## Configuration

- The script creates a backup of your existing `.bashrc` file and links a new configuration.
- You can customize the `.bashrc` and other configuration files located in the `my-bash` directory.

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository.
2. Create a new branch for your feature or bugfix.
3. Make your changes and commit them with clear messages.
4. Push your changes to your fork.
5. Submit a pull request to the main repository.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

## Acknowledgments

- [Oh My Posh](https://ohmyposh.dev/)
- [fzf](https://github.com/junegunn/fzf)
- [zoxide](https://github.com/ajeetdsouza/zoxide)
- [fastfetch](https://github.com/LinusDierheimer/fastfetch)