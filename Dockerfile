FROM ubuntu:16.04

# -----------------------------------------------------------------------------
# General environment variables
# -----------------------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive


# -----------------------------------------------------------------------------
# Install system basics
# -----------------------------------------------------------------------------
RUN \
  apt-get update -qqy && \
  apt-get install -qqy --allow-unauthenticated \
          apt-transport-https \
          python-software-properties \
          software-properties-common \
          curl \
          expect \ 
          zip \
          libsass-dev \
          git \
          sudo


# -----------------------------------------------------------------------------
# Install Java
# -----------------------------------------------------------------------------
ARG JAVA_VERSION
ENV JAVA_VERSION ${JAVA_VERSION:-8}

ENV JAVA_HOME ${JAVA_HOME:-/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64}

RUN \
  apt-get update -qqy && \
  apt-get install -qqy --allow-unauthenticated \
  openjdk-${JAVA_VERSION}-jdk


# -----------------------------------------------------------------------------
# Install Android / Android SDK / Android SDK elements
# -----------------------------------------------------------------------------

ENV ANDROID_SDK_ROOT /opt/android-sdk-linux
ENV PATH ${PATH}:${ANDROID_SDK_ROOT}/tools:${ANDROID_SDK_ROOT}/tools/bin:${ANDROID_SDK_ROOT}/platform-tools:/opt/tools

ARG ANDROID_PLATFORMS_VERSION
ENV ANDROID_PLATFORMS_VERSION ${ANDROID_PLATFORMS_VERSION:-25}

ARG ANDROID_BUILD_TOOLS_VERSION
ENV ANDROID_BUILD_TOOLS_VERSION ${ANDROID_BUILD_TOOLS_VERSION:-25.0.3}

RUN \
  echo ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT} >> /etc/environment && \
  dpkg --add-architecture i386 && \
  apt-get update -qqy && \
  apt-get install -qqy --allow-unauthenticated\
          libc6-i386 \
          lib32stdc++6 \
          lib32gcc1 \
          lib32ncurses5 \
          lib32z1 \
          qemu-kvm \
          kmod && \
  cd /opt && \
  mkdir android-sdk-linux && \
  cd android-sdk-linux && \
  curl -SLo sdk-tools-linux.zip https://dl.google.com/android/repository/sdk-tools-linux-3859397.zip && \
  unzip sdk-tools-linux.zip && \
  rm -f sdk-tools-linux.zip && \
  chmod 777 ${ANDROID_SDK_ROOT} -R  && \
  mkdir -p ${ANDROID_SDK_ROOT}/licenses && \
  echo 8933bad161af4178b1185d1a37fbf41ea5269c55 > ${ANDROID_SDK_ROOT}/licenses/android-sdk-license
# install gradle
RUN \
    mkdir /opt/gradle && \
    cd /opt/gradle && \
    curl -SLo gradle.zip "https://services.gradle.org/distributions/gradle-6.0.1-bin.zip" && \
    unzip gradle.zip && \
    export PATH=$PATH:/opt/gradle/gradle-6.0.1/bin

RUN \
  sdkmanager "tools" && \
  sdkmanager "platform-tools" && \
  sdkmanager "platforms;android-${ANDROID_PLATFORMS_VERSION}" && \
  sdkmanager "build-tools;${ANDROID_BUILD_TOOLS_VERSION}"


# -----------------------------------------------------------------------------
# Install Node, NPM, yarn
# -----------------------------------------------------------------------------
ARG NPM_VERSION
ENV NPM_VERSION ${NPM_VERSION:-6.13.1}


RUN \
  curl -sL https://deb.nodesource.com/setup_10.x | bash - && apt-get install -y nodejs && \
  ln -s /usr/local/bin/node /usr/local/bin/nodejs && \
  npm install -g npm@${NPM_VERSION}

RUN \
    npm install -g cordova && \
    npm install -g ionic && \
    npm install -g typescript && \
    npm install -g gulp &&\
    npm cache clean --force

# -----------------------------------------------------------------------------
# Clean up
# -----------------------------------------------------------------------------
RUN \
  apt-get clean && \
  apt-get autoclean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 


# -----------------------------------------------------------------------------
# Create a non-root docker user to run this container
# -----------------------------------------------------------------------------
ARG USER
ENV USER ${USER:-ionic}

RUN \
  # create user with appropriate rights, groups and permissions
  useradd --user-group --create-home --shell /bin/false ${USER} && \
  echo "${USER}:${USER}" | chpasswd && \
  adduser ${USER} sudo && \
  adduser ${USER} root && \
  chmod 770 / && \
  usermod -a -G root ${USER} && \

  # create the file and set permissions now with root user  
#  mkdir /app && chown ${USER}:${USER} /app && chmod 777 /app && \

  # create the file and set permissions now with root user
  touch /image.config && chown ${USER}:${USER} /image.config && chmod 777 /image.config && \

  # this is necessary for ionic commands to run
  mkdir /home/${USER}/.ionic && chown ${USER}:${USER} /home/${USER}/.ionic && chmod 777 /home/${USER}/.ionic && \

  # this is necessary to install global npm modules
  chmod 777 /usr/local/bin && \
  chown ${USER}:${USER} ${ANDROID_SDK_ROOT} -R


# -----------------------------------------------------------------------------
# Copy start.sh and set permissions 
# -----------------------------------------------------------------------------
COPY start.sh /start.sh
RUN chown ${USER}:${USER} /start.sh && chmod 777 /start.sh



# -----------------------------------------------------------------------------
# Generate an Ionic default app (do this with root user, since we will not
# have permissions for /app otherwise), install the dependencies
# and add and build android platform
# -----------------------------------------------------------------------------
RUN \
    cd / && \
    ionic config set -g backend legacy

#RUN ionic start app https://github.com/ionic-team/ionic-conference-app --type angular --no-deps --no-git
RUN ionic start app blank --type angular --no-deps --no-git
RUN chown -R ${USER}:${USER} /app && chmod -R 777 /app

USER ${USER}

ENV PATH $PATH:/opt/gradle/gradle-6.0.1/bin

RUN \
  cd /app && \
  npm install && \
  ionic cordova platform add android --no-resources
#  ionic cordova build android


# -----------------------------------------------------------------------------
# Just in case you are installing from private git repositories, enable git
# credentials
# -----------------------------------------------------------------------------
RUN git config --global credential.helper store


# -----------------------------------------------------------------------------
# WORKDIR is the generic /app folder. All volume mounts of the actual project
# code need to be put into /app.
# -----------------------------------------------------------------------------
WORKDIR /app


# -----------------------------------------------------------------------------
# The script start.sh installs package.json and puts a watch on it. This makes
# sure that the project has allways the latest dependencies installed.
# -----------------------------------------------------------------------------
ENTRYPOINT ["/start.sh"]


# -----------------------------------------------------------------------------
# After /start.sh the bash is called.
# -----------------------------------------------------------------------------
CMD ["ionic", "serve", "-b", "-p", "8100", "--address", "0.0.0.0"]
