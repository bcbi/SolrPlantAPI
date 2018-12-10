FROM julia:1.0.2

# Create app directory
RUN mkdir -p /usr/bin/solrplant_api
WORKDIR /usr/bin/solrplant_api

# Bundle app source
COPY . /usr/bin/solrplant_api

EXPOSE 8081

RUN echo "Installing Julia Packages"

RUN julia -e 'using Pkg; Pkg.activate(pwd()); Pkg.instantiate();'

CMD julia --project server.jl

# 172.17.0.2