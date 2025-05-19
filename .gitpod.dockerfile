FROM gitpod/workspace-base

# Install PostgreSQL 15 client and dependencies
RUN sudo apt-get update && \
    sudo apt-get install -y wget gnupg2 lsb-release curl redis-server \
      apt-transport-https ca-certificates software-properties-common && \
    echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - && \
    sudo apt-get update && \
    sudo apt-get install -y postgresql-client-15 && \
    sudo rm -rf /var/lib/apt/lists/*

# Install RVM and Ruby 3.2.7
RUN curl -sSL https://rvm.io/mpapis.asc | gpg --import - && \
    curl -sSL https://rvm.io/pkuczynski.asc | gpg --import - && \
    curl -sSL https://get.rvm.io | bash -s stable && \
    /bin/bash -c "source /home/gitpod/.rvm/scripts/rvm && \
                  rvm pkg install openssl && \
                  rvm install ruby-3.2.7 --with-openssl-dir=$HOME/.rvm/usr && \
                  rvm use ruby-3.2.7 --default"

ENV PATH="/home/gitpod/.rvm/bin:/home/gitpod/.rvm/gems/ruby-3.2.7/bin:$PATH"