FROM julia:0.6.2

# ----------------------Julia web-app specific packages--------------------------------
# my packages
ADD install_julia_pkgs.jl /tmp/install_julia_pkgs.jl
RUN julia /tmp/install_julia_pkgs.jl

# Create app directory
RUN mkdir -p /usr/bin/solrplant_api
WORKDIR /usr/bin/solrplant_api

# Bundle app source
COPY . /usr/bin/solrplant_api

EXPOSE 5005

CMD julia SolrPlantAPI.jl

# 172.17.0.2