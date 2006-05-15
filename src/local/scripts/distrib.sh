#! /bin/sh
do_lln=0
do_update=1
do_license=1
do_ChangeLog=1
do_doc=1
do_doxygen=1
do_zip_source=1
do_recon_test_pack=1
do_transfer=1

do_website_final_version=0
do_website_sync=0

set -e
VERSION=1.4

CVSOPTS="-d ha-beo-1:/data/home/kris/devel/cvsroot"
CVS="cvs $CVSOPTS"

# TODO  problems with LICENSE.txt
# need to get it without tag, and then update and then assign tag (potentially remove tag first)
#CHECKOUTOPTS="-r rel_1_30"
cd $WORKSPACE/../..

destination=$WORKSPACE/../web-site/
RSYNC_OPTS=

DISTRIB=`pwd`/distrib
LLN=${DISTRIB}/../lln
WORKSPACE=${DISTRIB}/parapet/PPhead 

# disable warnings as we currently get rid of any existing zip files
# reasons:
# - this will make sure we do not have files that are removed in the distro in the zip file
# - zip -u returns funny error code when updating a zip file

#if [ $do_doc = 1 -a -r ${DISTRIB}/STIR_doc_${VERSION}.zip ]; then
#  echo WARNING: updating existing zip file ${DISTRIB}/STIR_doc_${VERSION}.zip
#fi
#if [ $do_recon_test_pack = 1 -a -r ${DISTRIB}/recon_test_pack_${VERSION}.zip ]; then
#  echo "WARNING: updating existing zip file ${DISTRIB}/recon_test_pack_${VERSION}.zip"
#fi


mkdir -p ${DISTRIB}

if [ $do_lln = 1 ]; then
echo "LLN stuff "
cd ${LLN}
  trap "echo ERROR in LLN update" ERR
  $CVS up
  tar -v --exclude VC --exclude CVS -czf ecat.tar.gz \
    ecat/*[ch] ecat/Makefile.*   ecat/utils/*[ch] ecat/utils/Makefile.* 
fi

cd ${DISTRIB}

  trap "echo ERROR in cvs update" ERR
if [ ! -r parapet ]; then
    $CVS checkout -P  $CHECKOUTOPTS
  cd parapet
else
  cd parapet
  if [ $do_update = 1 ]; then
     trap "echo ERROR in CVS update" ERR
    $CVS up -dP  $CHECKOUTOPTS
  fi
fi
rm -f STIR
ln -s PPhead STIR
cd PPhead

# update VERSION.txt
echo "updating VERSION.txt"
echo "TODO update PROJECT_NUMBER in Doxyfile"
trap "echo ERROR in updating VERSION.txt" ERR
echo $VERSION > VERSION.txt
$CVS commit -m "- updated for release of version $VERSION" VERSION.txt

# update LICENSE.txt
if [ $do_license = 1 ]; then
  echo "updating LICENSE.txt"
  trap "echo ERROR in updating LICENSE.txt" ERR
  cd $WORKSPACE
  # put version in there
  cat LICENSE.txt | \
  sed "s/Licensing information for STIR .*/Licensing information for STIR $VERSION/" \
  > tmp_LICENSE.txt
  # remove list of files at the end (dangerous: relies on the text in the file)
  END_STRING="----------------------------------------------------"
  AWK_PROG="{ if( \$1 ~ \"$END_STRING\") {
                 exit 0;
            } else {
              print \$0
            }
          }"
  awk "$AWK_PROG" tmp_LICENSE.txt > LICENSE.txt
  echo $END_STRING >> LICENSE.txt
  #then add new list on again
  find . -path ./local -prune -path ./include/local -prune \
     -o -name "*[xhlkc]"  -print|grep -v CVS | xargs grep -l PARAPET >>LICENSE.txt 
  $CVS commit  -m "- updated for release of version $VERSION" LICENSE.txt
fi

# make ChangeLog file
if [ $do_ChangeLog = 1 ]; then
  trap "echo ERROR in updating ChangeLog" ERR
  echo Do ChangeLog
  cd $WORKSPACE
  # maybe use --accum
  rm -rf xxlocal
  mv local xxlocal
  cvs2cl.pl -g "$CVSOPTS" -I 'xxlocal/' -I 'include/local'  --no-indent -F trunk
  mv xxlocal local
  cp ChangeLog ${DISTRIB}
fi

if [ $do_doc = 1 ]; then
  echo "Making doc"
  trap "echo ERROR in updating doc" ERR
  cd $WORKSPACE
  # make doxygen
  if [ $do_doxygen = 1 ]; then
    doxygen
  fi
  # make documentation PDFs BY HAND
  cd ../documentation
  make
  rm -f ${DISTRIB}/STIR_doc_${VERSION}.zip
  zip -r ${DISTRIB}/STIR_doc_${VERSION}.zip *.pdf *.htm  doxy >/dev/null
fi

trap "echo ERROR after creating doc" ERR

if [ $do_zip_source = 1 ]; then
  echo Do zip source
  cd ${DISTRIB}
  rm -f parapet/all.zip parapet/VCprojects.zip
  zipit --distrib > /dev/null
  zipproj --distrib > /dev/null
  mv parapet/VCprojects.zip VCprojects_${VERSION}.zip 
  mv parapet/all.zip STIR_${VERSION}.zip 
fi

if [ $do_recon_test_pack = 1 ]; then
  cd ${DISTRIB}/parapet/
  echo Do zip recon_test_pack
  rm -f ../recon_test_pack_${VERSION}.zip
  #rm -rf recon_test_pack/CVS
  zip -r ../recon_test_pack_${VERSION}.zip recon_test_pack \
     -x  recon_test_pack/CVS/ recon_test_pack/CVS/* recon_test_pack/local/* recon_test_pack/local/ \
   > /dev/null
  #tar zcvf ../recon_test_pack_${VERSION}.tar.gz recon_test_pack
fi

if [ $do_transfer = 1 ]; then
  cd ${DISTRIB}
  chmod go+r *${VERSION}* ChangeLog
  chmod go-wx *${VERSION}* ChangeLog

  # put it all there
  rsync --progress -uavz ${RSYNC_OPTS}  ${LLN}/ecat/VC/ecat.dsp ${LLN}/ecat.tar.gz \
    STIR_${VERSION}.zip VCprojects_${VERSION}.zip \
    recon_test_pack_${VERSION}.zip \
    ${destination}registered
  rsync --progress -uavz ${RSYNC_OPTS} \
    ChangeLog STIR_doc_${VERSION}.zip  \
    ${destination}documentation
  echo "If you don't extract STIR_doc.zip, you might have to transfer parapet/documentation/release_${VERSION}.htm or similar explicitly."
fi

if [ $do_website_final_version = 1 ]; then
    cd $destination
    cd registered
    rm  recon_test_pack.tar.gz STIR.zip VCprojects.zip recon_test_pack.zip 
    ln -s STIR_${VERSION}.zip STIR.zip 
    ln -s VCprojects_${VERSION}.zip  VCprojects.zip
    #ln -s recon_test_pack_${VERSION}.tar.gz  recon_test_pack.tar.gz 
    ln -s recon_test_pack_${VERSION}.zip recon_test_pack.zip
	cd ../documentation
    rm STIR_doc.zip
    ln -s STIR_doc_${VERSION}.zip STIR_doc.zip 
    rm -fr doxy
    unzip -u STIR_doc
    cd ..
fi

if [ $do_website_sync = 1 ]; then
    # rsync of website note: stalls on gluon,wren,hurricane, but works fine from shark
    cd $destination
    rsync  -auCzv --rsync-path=/home/kris/bin/rsync ./ web@wren:htdocs/STIR/
    rsync  -auCzv ./ krthie@shell.sf.net:stir/htdocs/    
fi