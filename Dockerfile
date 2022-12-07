## Temporary image to build the libraries and only save the needed artifacts
FROM osgeo/gdal:ubuntu-full-3.1.2 AS builder
WORKDIR /opt/builder
ARG dataDir=/data
ARG projectDir=/foss_fim
ARG depDir=/dependencies
ARG taudemVersion=98137bb6541a0d0077a9c95becfed4e56d0aa0ac
ARG taudemVersion2=81f7a07cdd3721617a30ee4e087804fddbcffa88
ENV taudemDir=$depDir/taudem/bin
ENV taudemDir2=$depDir/taudem_accelerated_flowDirections/taudem/build/bin

RUN apt update && \ 
    DEBIAN_FRONTEND=noninteractive apt install -y git && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/dtarb/taudem.git
RUN git clone https://github.com/fernandoa123/cybergis-toolkit.git taudem_accelerated_flowDirections

RUN apt update --fix-missing && \
    DEBIAN_FRONTEND=noninteractive apt install -y cmake mpich \
            libgtest-dev libboost-test-dev libnetcdf-dev && \
    rm -rf /var/lib/apt/lists/*

## Compile Main taudem repo ##
RUN mkdir -p taudem/bin
RUN cd taudem \
    && git checkout $taudemVersion \
    && cd src \
    && make

## Compile taudem repo with accelerated flow directions ##
RUN cd taudem_accelerated_flowDirections/taudem \
    && git checkout $taudemVersion2 \
    && mkdir build \
    && cd build \
    && cmake .. \
    && make

RUN mkdir -p $taudemDir
RUN mkdir -p $taudemDir2

# Make symlink for libgdal
#RUN ln -s /usr/lib/libgdal.so.3.1.2 /usr/lib/libgdal.so.31

## Move needed binaries to the next stage of the image
RUN cd taudem/bin && mv -t $taudemDir flowdircond aread8 threshold streamnet gagewatershed catchhydrogeo dinfdistdown
RUN cd taudem_accelerated_flowDirections/taudem/build/bin && mv -t $taudemDir2 d8flowdir dinfflowdir




###############################################################################################



# Base Image that has GDAL, PROJ, etc
FROM osgeo/gdal:ubuntu-full-3.1.2
ARG dataDir=/data
ARG projectDir=/foss_fim
ARG depDir=/dependencies
ENV inputDataDir=$dataDir/inputs
ENV outputDataDir=$dataDir/outputs
ENV srcDir=$projectDir/src
ENV taudemDir=$depDir/taudem/bin
ENV taudemDir2=$depDir/taudem_accelerated_flowDirections/taudem/build/bin

## ADDING FIM GROUP ##
ARG GroupID=1370800235
ARG GroupName=fim
RUN addgroup --gid $GroupID $GroupName
ENV GID=$GroupID
ENV GN=$GroupName

RUN mkdir -p $depDir
COPY --from=builder $depDir $depDir

RUN apt update --fix-missing && \
    DEBIAN_FRONTEND=noninteractive apt install -y p7zip-full python3-pip time \
            mpich=3.3.2-2build1 parallel=20161222-1.1 \
            libgeos-dev=3.8.0-1build1 expect=5.45.4-2build1 \
            grass=7.8.2-1build3 grass-doc=7.8.2-1build3 \ 
            graphviz=2.42.2-3build2 && \
    apt auto-remove && \
    rm -rf /var/lib/apt/lists/*

## adding environment variables for numba and python ##
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV PYTHONUNBUFFERED=TRUE

## ADD TO PATHS ##
ENV PATH="$projectDir:${PATH}"
ENV PYTHONPATH=${PYTHONPATH}:$srcDir:$projectDir/tests:$projectDir/tools

## install python 3 modules ##
COPY requirements.txt .
RUN python3 -m pip install -r requirements.txt

## RUN UMASK TO CHANGE DEFAULT PERMISSIONS ##
ADD ./src/entrypoint.sh /
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
