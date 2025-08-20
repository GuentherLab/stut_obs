# README

Scripts used for fMRI or behavioral-only experiments which involves audio stimuli presentation and/or response recording at GuentherLab.

Script written by Alfonso Nieto-Castanon & Jason Tourville, and Haochen Wan @ Guenther lab

Readme written by Haochen

Different versions of scripts designed for different [**task**].
* flvoice_run: General script (such as [**test**], [**train**], [**prepost**])
* flvoice_run_CTOPP: Script modified for pre-scan behavioral tests (nonword repetition test [**nr**] and memory for digits test [**md**])
* flvoice_run_pairs: Script modified for pre-scan bahavioral tests (nonspeech pair identification test [**pr**])

## flvoice_run.m
_Input_

    [root]/sub-[subject]/ses-[session]/beh/[task]/sub-[subject]_ses-[session]_run-[run]_task-[task]_desc-stimulus.txt     : INPUT list of stimulus NAMES W/O suffix (one trial per line; enter empty audiofiles or the string NULL for NULL -no speech- conditions)

    [root]/sub-[subject]/ses-[session]/beh/[task]/sub-[subject]_ses-[session]_run-[run]_task-[task]_desc-conditions.txt   : (optional) INPUT list of condition labels (one trial per line). if unspecified, condition labels are set to stimulus filename
    
    [audiopath]/[task]/                       : path for audio stimulus files (.wav)
    
    [figurespath]/                            : path for image stimulus files (.png) [if any]
    
    The above two should match names in stimulus.txt

 _Output_
    
    [root]/sub-[subject]/ses-[session]/beh/[task]/sub-[subject]_ses-[session]_run-[run]_task-[task]_desc-audio.mat        : OUTPUT audio data (see FLVOICE_IMPORT for format details) 

_StepbyStep\_Instructions_

0. Before you start.
    + Audio settings. Current audio devices setting follows naming convention when you use a focusrite in your setup. Subject mic channel is called 'Analogue,' computer output is called 'Speakers,' and scanner trigger uses the 'Playback' channel. Please change correspondingly if you are using a different audio setup; more specifically, change the definition of `ipind`, `opind`, and `tgind`. These default audio device indices are defined by looking them up in the audio device strings returned by the system.
    + Display settings. Dual display with 'extension' config needed.

1. Prepare stimuli in any directory you desire, but they should be organized as `[audiopath]/[task]/audio_stimuli_files` and `[figurespath]/visual_stimuli_files`, with [audiopath], [figurespath], [task] being corresponding inputs to the preset config files (see step 2) or GUI (see step 5). Figures (.png) should have the same filenames as the corresponding audio stimuli (.wav).

2. Create preset config (.json) files using `write_preset_configs.m`. The config files include all needed experimental parameters including visual display settings, timing control settings, and fMRI scan settings. To minimize the need to change values when running the experiment, preset config files can be generated for each different tasks. 
    1. Preset config files should be saved in `[root]/[config]`
    2. Detailed description for each entry:
    *  **visual**: 
        * figure: show images during audio presentation & response period (default: black on white)
        * fixpoint: show cross fixpoint during whole experiments with color changing in response period
        * orthography: show word orthographically together with audio presentation
    * **root**: Directory to save beh results. (Should be project root folder if in BIDS format.)
    * **audiopath**: Directory where audio stimuli saved (.wav).
    * **figurespath**: Directory where visual stimuli saved (.png).
    * task: Task name. Should match sub-folder names in **audiopath**.
    * **scan**: fMRI scan or not (true/false).
    * **timePostStim**: time (s) from end of the stimulus presentation to the GO signal (one value for fixed time, two values for minimum-maximum range of random times) [.25 .75] 
    * **timePostOnset**: time (s) from subject's voice onset to the scanner trigger (or to pre-stimulus segment, if scan=false) (one value for fixed time, two values for minimum-maximum range of random times) [4.5] 
    * **timeMax**: maximum time (s) before GO signal and scanner trigger (or to pre-stimulus segment, if scan=false) (recording portion in a trial may end before this if necessary to start scanner) [5.5] 
    * timeScan: (if scan=true) duration (s) of scan (one value for fixed time, two values for minimum-maximum range of random times) [1.6] 
    * **timePreStim**: time (s) from end of scan to start of next trial stimulus presentation (one value for fixed time, two values for minimum-maximum range of random times) [.25] 
    * timePreSound: (if visual is 'orthography', otherwise keep 0) time (s) from start of orthographic presentation to the start of sound stimulus [.5]
    * timePostSound: (if visual is 'orthography', otherwise keep 0) time (s) from end of sound stimulus to the end of orthographic presentation [.47]
    * **minVoiceOnsetTime**: time (s) to exclude from onset detection (use when beep sound is recorded) [0.4]
    * prescan: (if scan=true) true/false include prescan sequence at the beginning of experiment [1] 
    * **rmsThresh**: voice onset detection: initial voice-onset root-mean-square threshold [.02]
    * **rmsBeepThresh**: beep onset detection: initial beep-onset root-mean-square threshold [.1]
    * **rmsThreshTimeOnset**: voice onset detection: mininum time (s) for intentisy to be above RMSThresh to be consider voice-onset [0.02] 
    * ipatDur: prescan sequence: prescan IPAT duration (s) [4.75] 
    * smsDur: prescan sequence: prescan SMS duration (s) [7] 
    * deviceMic: keep blank (change in GUI)
    * deviceHead: keep blank (change in GUI)
    * deviceScan: keep blank (change in GUI)


3. Prepare subject folder with stimulus lists (and condition lists, if applicable).
    + This should be completed via script starting with `setup_subj`. **DO NOT make them manually unless needed.**

    * specifications when creating manually:
        + stimulus lists should be named as `[root]/sub-[subject]/ses-[session]/beh/[task]/sub-[subject]_ses-[session]_run-[run]_task-[task]_desc-stimulus.txt`
            + Each line is one filename **without suffix** (see step 7).
            + folder name supported. (e.g., `folderA/sound1.wav` will be recognized as file `sound1.wav` in `[audiopath]/[task]/folderA`.)
            + MacOS ('/') and Win ('\\') paths both supported.
            + Use NULL for non-speech trials.

        + condition lists should be named as `[root]/sub-[subject]/ses-[session]/beh/[task]/sub-[subject]_ses-[session]_run-[run]_task-[task]_desc-conditions.txt`
            + Each line is one condition name, e.g., 'N'
            + Use NULL for non-speech trials.
            + When condition lists not provided, condition will be the same as the filename provided in stimulus lists


4. Run script with no additional input parameters. The first prompt window will ask for a preset config (.json) file. Choose one and click continue, or click skip.

5. The second prompt window will ask you to confirm parameters and make necessary changes. If appropriate preset config file is used, you will only need to change *subject ID, #session, #run, gender, and audio settings* everytime you run a different subject and not others.

6. A third prompt window will popup if the result files already present. You can choose from overwritting or cancelling. Be extra careful subject ID, session, and run numbers are correct.

7. Other settings you may want to change:
    + default_fontsize: change display font size. Also support host-computer recognition.
    + stimulus suffix
        + audio: search and change lines related to `Input_files`
        + figure: search and change lines related to `All_figures_str` and `figures`.

## flvoice_run_CTOPP.m

_Input_

    [audiopath]/[task]/desc-stimulus.txt           : INPUT list of stimulus NAMES W/ suffix
    [audiopath]/[task]/desc-stimulus_prac.txt      : same as above, for practice trials
    [audiopath]/[task]/desc-conditions.txt         : INPUT list of correct answers (numbers or nonwords)
    [audiopath]/[task]/desc-conditions_prac.txt    : same as above, for practice trials
    [audiopath]/[task]                       : path for audio stimulus files (.wav)
    The above should match names in stimulus.txt

_Output_

    [root]/sub-[subject]/ses-[session]/beh/[task]/sub-[subject]_ses-[session]_run-[run]_task-[task]_desc-audio.mat        : OUTPUT audio data (see FLVOICE_IMPORT for format details) 

_Instructions_

0. Before you start:
    + expParams structure contains parameters that define the experiment protocol. Refer to the flvoice_run.m for detailed definition. Most importantly, change the 'root' field to the path you'd like to save the results.
    + Audio settings. Change the definition of `ipind` and `opind` if needed. Refer to the flvoice_run.m for detailed definition.
    + Display settings. Dual display with 'extension' config needed.

1. Make sure all parameters in the GUI are correct for your experiments (especially task name, visual presentation type, subject info, and audio devices) before starting the experiment.

2. No scanning involved.

3. Config files are not subject-specific.

4. Operator input is required, e.g.:

    a. Start of trial one.
    
    b. Audio stimuli played.

    c. Go signal played. {from here: 'finish trial' button available in the realtime waveform window}

    d. **[Operator]** ends this trial when subject finished responding.

    e. **[Operator]** judges correctness and input 1/0 for correct/incorrect.

    f. After three consecutive 0s detected, **[Operator]** will be asked whether to finish the test or not.

    g. If **[Operator]** do not wish to finish the test, follow the prompt and change the newest 3 correctness answers. If changed, **The separated log parameter {correct} will be changed, but the log file for individual trial will still contain the old input.**

    h. Such change in g will also be logged into the "comments" parameter, therefore manual input not needed.

    i. **[Operator]** will be prompt to enter additional comment if necessary. Suggest to always type in operater initial.

5. Practice runs can be performed by defining subject ID as PRAC. In that case, the script will use _prac versions of stimulus and condition lists, instead of the regular version. Practice runs results will be overwritten by the next subject.

## flvoice_run_pairs.m

_Input_
    
    [audiopath]/[task]/desc-stimulus.txt                   : INPUT list of stimulus NAMES W/ suffix (words)
    [audiopath]/[task]/desc-stimulus_prac.txt              : same as above, but for practice runs
    [audiopath]/[task]/desc-stimulus1(/2/3).txt            : INPUT list of stimulus NAMES W/ suffix (choices 1/2/3)
    [audiopath]/[task]/desc-stimulus1_prac(/2/3).txt       : same as above, but for practice runs
    [audiopath]/[task]/desc-conditions.txt                 : INPUT list of correct answers (1, 2, or 3)
    [audiopath]/[task]/desc-conditions_prac.txt            : same as above, but for practice runs
    [audiopath]/[task]                       : path for audio stimulus files (.wav)
    The above should match names in stimulus.txt or stimulus2.txt

_Output_

    [root]/sub-[subject]/ses-[session]/beh/[task]/sub-[subject]_ses-[session]_run-[run]_task-[task]_trial-[trial].mat        : Saved exp info

_Instructions_

0. Before you start:
    + expParams structure contains parameters that define the experiment protocol. Refer to the flvoice_run.m for detailed definition. Most importantly, change the 'root' field to the path you'd like to save the results.
    + Audio settings. Change the definition of `opind` if needed. Refer to the flvoice_run.m for detailed definition.
    + Display settings. Dual display with 'extension' config needed.
    

1. Make sure all parameters in the GUI are correct for your experiments (especially task name, visual presentation type, subject info, and audio devices) before starting the experiment.

2. No scanning & audio recording involved.

3. Config files are not subject-specific.

4. Operator input is required, e.g.:

    a. Start of trial one.
    
    b. Audio stimuli played.

    c. Go signal played. {from here: **Subject** will be prompted to enter 1 or 2 or 3 with their keyboard}

    d. **[Operator]** DOESN'T need to judge correctness. It will be automatically calculated by comparing config file (conditions) with subject input.

    e. **[Operator]** will be prompt to enter additional comment if necessary. Suggest to always type in operater initial.

5. Practice runs can be performed by defining subject ID as PRAC. In that case, the script will use _prac versions of stimulus and condition lists, instead of the regular version. Practice runs results will be overwritten by the next subject.

    ADDITIONAL note for MacOS user:
    The keyboard input may not be recorded by Matlab command window, even when the focus is there. That will lead to unrecorded subject input. Two solutions (either works): 
    
    1. Undock the command window from MATLAB main window before starting the experiment
    
    2. Click the command window on the operator side immediately after the experiment has begun.



## play_recordings.m
As it suggests in the name, this script playback recordings saved in .mat format.

## setUpVisAnnot_HW.m
Setup display screen and common display objects, including a text box and a image box.

## save_wav.m
Save audio recordings in .mat result files as .wav files, separated by each trial.

## setup_subj_*
Automatically create desc text files ('stimulus' and 'condition') that **flvoice_run** uses. (flvoice_run_CTOPP or flvoice_run_pairs don't need this step.) Please refer to the comments of each individual script for usage description.

## testMicHeadphones.m
Calibrate audio system with predefined config files.

## testMicHeadphones_standalone.m
Calibrate audio system without a predefined config file. (Parameter hard coded).
+ Before you start:
    + Audio settings. Change the definition of `ipind` and `opind` if needed. Refer to the flvoice_run.m for detailed definition.
    + Display settings. Dual display with 'extension' config needed.