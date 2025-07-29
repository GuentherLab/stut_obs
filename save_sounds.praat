form Enter directory to save your sounds
	sentence directory TYPE YOUR DIR HERE
endform

pause select all sounds to save
numOfSounds = numberOfSelected ("Sound")

for thisSelectedSound to numOfSounds
	sound'thisSelectedSound' = selected("Sound", thisSelectedSound)
endfor

for thisSound from 1 to numOfSounds
	select sound'thisSound'
	name$ = selected$("Sound")
	do ("Save as 32-bit WAV file...", directory$ + "/" + name$ + ".wav")
endfor

#re-select the sounds
select sound1
for thisSound from 2 to numOfSounds
	plus sound'thisSound'
endfor