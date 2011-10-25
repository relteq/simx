cd apiweb
mkdir -p ../var/data

export APIWEB_DB_URL=sqlite:///home/vjoel/simx/var/data/apiweb.sqlite
import-aurora $APIWEB_DB_URL doc/tiny.xml

export GMAP_KEY=ABQIAAAAYXmdMORPx7C3RCOTwVFpixS46uheWFfa9NCS7XJB4BvQftvBtxSGE3QuJoH9P49v-NBaQlrGrNqevw

rake start


NE_DIR ???

APIWEB_S3_BUCKET
AMAZON_ACCESS_KEY_ID
AMAZON_SECRET_ACCESS_KEY
