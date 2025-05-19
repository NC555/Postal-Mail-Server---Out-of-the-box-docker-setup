FROM ghcr.io/postalserver/postal:latest

RUN set -e \
    && apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y zsh nano \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN chsh -s $(which zsh) root
RUN usermod --shell $(which zsh) postal

EXPOSE 5000
CMD ["postal", "start"]
