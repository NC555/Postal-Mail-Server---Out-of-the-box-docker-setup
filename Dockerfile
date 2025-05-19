# Use the postalserver.io base image
FROM ghcr.io/postalserver/postal:latest

# Update the package manager and install zsh and nano
RUN apt-get update \
  && apt-get install -y zsh nano \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Set zsh as the default shell
RUN chsh -s $(which zsh) root

# Assign zsh as the default shell for the postal user if it exists
RUN usermod --shell $(which zsh) postal

# Expose Postal port
EXPOSE 5000

# Define the default command
CMD ["postal", "start"]
