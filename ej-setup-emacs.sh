# emacs-29
emacs_dir='emacs-29.2'

cd /tmp
wget -c https://ftp.gnu.org/gnu/emacs/$emacs_dir.tar.gz
tar -xvf $emacs_dir.tar.gz
cd $emacs_dir

CC="gcc-10" ./autogen.sh
sai texinfo \
    xaw3dg-dev \
    gcc-10 \
    build-essential \
    libgccjit-10* \
    acl \
    libacl1* \
    xaw3dg* \
    xaw3dg-dev \
    libmagickwand-dev \
    libm17n-dev \
    libmagickcore-dev \
    libgtk-3-dev \
    libwebkit2gtk-4.0-dev \
#    libghc-gnutls-dev \
    libgnutls30 \
    libwebkit2gtk-4.1-dev \
    giflib-tools \
    libgif7 \
    libgif-dev \
    libgnutls28-dev \
    libtree-sitter-dev \
    libjansson4 \
    libjansson-dev \
    imagemagick-6.q16hdri \
    dvipng

# mmap not supported yet...
CC="gcc-10" ./configure  --with-mailutils --with-imagemagick --with-xwidgets --with-native-compilation --with-libsystemd --with-x-toolkit=gtk3 --with-gconf --with-gpm --with-m17n-flt --with-libotf --with-xft

numcpus=`grep -c '^processor' /proc/cpuinfo`
make -j $numcpus
sudo make -j $numcpus install
