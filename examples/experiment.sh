#!/bin/bash

#haswell i7-4770k
line_size=64
l1size=32768
l2size=262144
#l3size=8388608
l3size=2097152
l1ways=8
l2ways=8
l3ways=16
threads=4

#xeon x5-2630
#l1size=32768
#l2size=262144
#l3size=16777216 # should be 15MB (whatever that means)
#l3size=3145728 # should be 15MB / 6
#threads=6

#l1ways=8
#l2ways=8
#l3ways=20 #blerggg

l1code=r5301d1 # MEM_LOAD_UOPS_RETIRED:L1_hit
#l2code=r530324
l2code=r53e724 # L2_RQSTS:ALL_DEMAND_DATA_RD
l3code=r534f2e # LLC_REFERENCES
#memcode=r53012e
memcode=r50412e # LAST_LEVEL_CACHE_MISSES

executable=../bin/CoMD-openmp
export OMP_NUM_THREADS=$threads
export OMP_PLACES=cores

iters=10

get_probsize(){
    local res
    let "res=4*$1**3"
    echo -n "$res"
}

pow2(){
    for x in $*
    do
        echo "2^$x" | bc
    done
}

files="byfl.out perf.out"
for file in $files
do
    echo -e "problem size\tl1 accesses\tl2 accesses\tl3 accesses\t mem accesses" > $file
done

#for size in 4 6 8 10 12 14 16 17 18 19 20 25
for size in 10 12 14 16 17 18 19 20
do
    # initialize output files
    probsize=$(get_probsize $size)
    for file in $files
    do
        echo -e -n "$probsize\t" >> $file
    done

    #get perf counter values
    l1val=0
    l2val=0
    l3val=0
    memval=0
    for count in `seq $iters`
    do
        perf stat -e $l1code,$l2code,$l3code,$memcode $executable-orig -e -i 1 -j 1 -k 1 -x $size -y $size -z $size -N 1 2>&1 | tee perf.tmp
        let "l1val=$l1val+$(grep $l1code perf.tmp | awk '{print $1}' | tr -d ',')"
        let "l2val=$l2val+$(grep $l2code perf.tmp | awk '{print $1}' | tr -d ',')"
        let "l3val=$l3val+$(grep $l3code perf.tmp | awk '{print $1}' | tr -d ',')"
        let "memval=$memval+$(grep $memcode perf.tmp | awk '{print $1}' | tr -d ',')"
        rm perf.tmp
    done
    let "l1val=l1val/$iters"
    let "l2val=l2val/$iters"
    let "l3val=l3val/$iters"
    let "memval=memval/$iters"
    echo -e "$l1val\t$l2val\t$l3val\t$memval" >> perf.out

    #get byfl and dinero values
    $executable-byfl -e -i 1 -j 1 -k 1 -x $size -y $size -z $size -N 1
    bf-parse-cache-dump private-cache.dump remote-shared-cache.dump --ways $l1ways $l2ways $l3ways --sizes $l1size $l2size $l3size --shared-llc --threads $threads >> byfl.out

    #save outputs for later reference
    mkdir dumps_$size
    #mv cache.*.dump dumps_$size
    mv {private,shared,remote-shared}-cache.dump dumps_$size
done
