# Utilise Ruby latest comme image de base
FROM ruby:latest

# Définit le répertoire de travail
WORKDIR /docs

# Installe les dépendances système
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copie les fichiers de dépendances
COPY Gemfile* ./

# Installe bundler et les gems
RUN gem install bundler jekyll webrick csv bigdecimal \
    && bundle install

# Copie le reste des fichiers
COPY . .

# Expose le port 4000
EXPOSE 4000

# Définit le point d'entrée
ENTRYPOINT ["bundle", "exec", "jekyll", "serve", "--host=0.0.0.0", "--port=4000", "--baseurl="]