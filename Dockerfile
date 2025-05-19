# Use the postalserver.io as the base image
FROM ghcr.io/postalserver/postal:latest

# Update the package manager and install zsh and nano
RUN apt-get update && apt-get install -y \
    zsh \
    nano \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Switch the default shell to zsh for the root user
RUN chsh -s $(which zsh) root

# If Postal uses a specific user, set zsh as default for that user as well
RUN usermod --shell $(which zsh) postal

# Optionally set up zsh configuration, such as oh-my-zsh, if desired
# RUN sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"

# Expose necessary ports
EXPOSE 5000

# Run the Postal command (adjust if necessary)
CMD ["postal", "start"]
