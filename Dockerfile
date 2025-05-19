FROM ghcr.io/postalserver/postal:latest

# Switch to root user for package installation
USER root

# Update and install necessary packages
RUN set -e \
    && apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y zsh nano \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Optionally, switch back to 'postal' user if it exists and is the intended user for running the application
# Replace 'postal' with the appropriate user if necessary
# USER postal

# Set zsh as the default shell for root and postal users
RUN chsh -s $(which zsh) root \
    && usermod --shell $(which zsh) postal

EXPOSE 5000

CMD ["postal", "start"]
