FROM julia:1.0.2

# Basic OS dependencies
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get -yq dist-upgrade \
    && apt-get install -yq --no-install-recommends \
    wget \
    bzip2

# ****************************** Conda and Python***************************
# Configure environment
ENV CONDA_DIR=/opt/conda 
ENV PATH=$CONDA_DIR/bin:$PATH
ENV MINICONDA_VERSION 4.5.11

# Install conda and check the md5 sum provided on the download site
RUN cd /tmp && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    echo "e1045ee415162f944b6aebfe560b8fee *Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh" | md5sum -c - && \
    /bin/bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    conda config --system --prepend channels conda-forge && \
    conda config --system --set auto_update_conda false && \
    conda config --system --set show_channel_urls true && \
    conda install --quiet --yes conda="${MINICONDA_VERSION%.*}.*" && \
    conda update --all --quiet --yes && \
    conda clean -tipsy

RUN conda install -c conda-forge --quiet --yes \
    nltk \
    textblob

RUN python -c 'import nltk; nltk.download("punkt"); nltk.download("conll2000");'

# Create app directory
RUN mkdir -p /usr/bin/solrplant_api/src
WORKDIR /usr/bin/solrplant_api
# Bundle app source
COPY src /usr/bin/solrplant_api/src

EXPOSE 8081

ENV CONDA_JL_HOME=/opt/conda

RUN echo `which python`
ENV PYTHON=/opt/conda/bin/python

RUN echo "Installing Julia Packages"

RUN julia -e 'using Pkg; Pkg.activate(pwd()); Pkg.instantiate();'

COPY server.jl /usr/bin/solrplant_api/

CMD julia --project server.jl

# # 172.17.0.2