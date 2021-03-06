#!/bin/bash

. $(dirname $0)/../include.rc
. $(dirname $0)/../volume.rc

function get_mtime {
        local f=$1
        stat $f | grep Modify | awk '{print $2 $3}' | cut -f1 -d'.'
}
cleanup;

## Tests if mtime is correct after self-heal.
TEST glusterd
TEST pidof glusterd
TEST mkdir -p $B0/gfs0/brick0{1,2}
TEST $CLI volume create $V0 replica 2 transport tcp $H0:$B0/gfs0/brick01 $H0:$B0/gfs0/brick02
TEST $CLI volume set $V0 nfs.disable on
TEST $CLI volume set $V0 performance.stat-prefetch off
TEST $CLI volume set $V0 cluster.background-self-heal-count 0
TEST $CLI volume set $V0 cluster.self-heal-daemon off
TEST $CLI volume start $V0
TEST glusterfs --volfile-id=/$V0 --volfile-server=$H0 $M0 --direct-io-mode=enable
# file 'a' is healed from brick02 to brick01 where as file 'b' is healed from
# brick01 to brick02

TEST cp -p /etc/passwd $M0/a
TEST cp -p /etc/passwd $M0/b

#Store mtimes before self-heals
TEST modify_atstamp=$(get_mtime $B0/gfs0/brick02/a)
TEST modify_btstamp=$(get_mtime $B0/gfs0/brick02/b)

TEST $CLI volume stop $V0
TEST gf_rm_file_and_gfid_link $B0/gfs0/brick01 a
TEST gf_rm_file_and_gfid_link $B0/gfs0/brick02 b

TEST $CLI volume start $V0 force
EXPECT_WITHIN 20 "1" afr_child_up_status $V0 0
EXPECT_WITHIN 20 "1" afr_child_up_status $V0 1

TEST $CLI volume set $V0 cluster.self-heal-daemon on
sleep 1
TEST gluster volume heal $V0 full

size=`stat -c '%s' /etc/passwd`
EXPECT_WITHIN 60 $size stat -c '%s' $B0/gfs0/brick01/a

TEST modify_atstamp1=$(get_mtime $B0/gfs0/brick01/a)
TEST modify_atstamp2=$(get_mtime $B0/gfs0/brick02/a)
EXPECT $modify_atstamp echo $modify_atstamp1
EXPECT $modify_atstamp echo $modify_atstamp2

TEST modify_btstamp1=$(get_mtime $B0/gfs0/brick01/b)
TEST modify_btstamp2=$(get_mtime $B0/gfs0/brick02/b)
EXPECT $modify_btstamp echo $modify_btstamp1
EXPECT $modify_btstamp echo $modify_btstamp2
cleanup;
