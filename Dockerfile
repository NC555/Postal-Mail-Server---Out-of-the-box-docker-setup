FROM ghcr.io/postalserver/postal:latest

RUN apt-get update && apt-get upgrade -y \
  && apt-get install -y zsh nano \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Optionally, verify the installation
RUN zsh --version && nano --version

# Set zsh as the default shell
RUN chsh -s $(which zsh) root
RUN usermod --shell $(which zsh) postal

EXPOSE 5000
CMD ["postal", "start"]
