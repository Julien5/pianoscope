set terminal pngcairo size 1200,600
set output '/tmp/tmp.png'
set title 'Last {count} Samples'
set xlabel 't (s)'
set ylabel 'y'
set grid

set style fill transparent solid 0.35 border

# set autoscale x
# set autoscale y
set xrange [0:{WINDOW_SECONDS}]
set yrange [-0.1:0.1]

plot '{audio_csv}' using 1:2 with lines title 'Signal', \
     '{pitch_csv}' using 2:4:3 with boxes title 'Energy', \
     '{pitch_csv}' using 1:5 with lines dashtype 2 lc rgb 'red' title 'Threshold', \
     '{pitch_csv}' using 1:6 with lines dashtype 3 lc rgb 'blue' title 'min', \
     '{pitch_csv}' using 1:7 with lines dashtype 4 lc rgb 'blue' title 'max'


