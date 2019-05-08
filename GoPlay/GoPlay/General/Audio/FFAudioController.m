//
//  FFAudioController.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/15.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFAudioController.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import "FFHeader.h"

static int const max_frame_size = 4096;
static int const max_chan = 2;

typedef struct
{
    AUNode node;
    AudioUnit audioUnit;
} FFAudioNodeContext;

typedef struct
{
    AUGraph graph;
    FFAudioNodeContext converterNodeContext;
    FFAudioNodeContext mixerNodeContext;
    FFAudioNodeContext outputNodeContext;
    AudioStreamBasicDescription asbd;
} FFAudioOutputContext;

@interface FFAudioController()
{
     float * _outData;
}

@property(nonatomic,assign) FFAudioOutputContext *outputContext;
@property (nonatomic, strong) AVAudioSession * audioSession;
@property (nonatomic, assign) BOOL registered;
@end

@implementation FFAudioController

+ (instancetype)controller
{
    static FFAudioController * obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[self alloc] init];
    });
    return obj;
}

- (instancetype)init
{
    if (self = [super init])
    {
        self->_outData = (float *)calloc(max_frame_size * max_chan, sizeof(float));

        self.audioSession = [AVAudioSession sharedInstance];
        [[NSNotificationCenter defaultCenter]  addObserver:self
												  selector:@selector(audioSessionInterruptionHandler:)
													  name:AVAudioSessionInterruptionNotification
													object:nil];

        [[NSNotificationCenter defaultCenter]  addObserver:self
												  selector:@selector(audioSessionRouteChangeHandler:)
													  name:AVAudioSessionRouteChangeNotification
													object:nil];
    }
    return self;
}

- (BOOL)registerAudioSession
{
    if (!self.registered)
    {
        if ([self setupAudioUnit])
        {
            self.registered = YES;
			self.volume = 1.0;
        }
    }
    
    [self.audioSession setActive:YES error:nil];
    return self.registered;
}

- (void)unregisterAudioSession
{
    if (self.registered)
    {
        self.registered = NO;
        OSStatus result = AUGraphUninitialize(self.outputContext->graph);
        checkError(result, @"graph uninitialize error");
        
        result = AUGraphClose(self.outputContext->graph);
        checkError(result, @"graph close error");

        result = DisposeAUGraph(self.outputContext->graph);
        checkError(result, @"graph dispose error");

        if (self.outputContext)
        {
            free(self.outputContext);
            self.outputContext = NULL;
        }
    }
}

- (BOOL)setupAudioUnit
{
    OSStatus result;
    UInt32 audioStreamBasicDescriptionSize = sizeof(AudioStreamBasicDescription);;
    
    self.outputContext = (FFAudioOutputContext *)malloc(sizeof(FFAudioOutputContext));
    memset(self.outputContext, 0, sizeof(FFAudioOutputContext));
    
    NSError* error = nil;
    result = NewAUGraph(&self.outputContext->graph);
    error = checkError(result, @"create  graph error");
    if(error) return NO;
    
    AudioComponentDescription converterDescription;
    converterDescription.componentType = kAudioUnitType_FormatConverter;
    converterDescription.componentSubType = kAudioUnitSubType_AUConverter;
    converterDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    result = AUGraphAddNode(self.outputContext->graph, &converterDescription, &self.outputContext->converterNodeContext.node);
    error = checkError(result, @"graph add converter node error");
    if(error) return NO;
    
    AudioComponentDescription mixerDescription;
    mixerDescription.componentType = kAudioUnitType_Mixer;
    mixerDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;

    mixerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    result = AUGraphAddNode(self.outputContext->graph, &mixerDescription, &self.outputContext->mixerNodeContext.node);
    error = checkError(result, @"graph add mixer node error");
    if(error) return NO;
    
    AudioComponentDescription outputDescription;
    outputDescription.componentType = kAudioUnitType_Output;
    outputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
    outputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    result = AUGraphAddNode(self.outputContext->graph, &outputDescription, &self.outputContext->outputNodeContext.node);
    error = checkError(result, @"graph add output node error");
    if(error) return NO;
    
    result = AUGraphOpen(self.outputContext->graph);
    error = checkError(result, @"open graph error");
    if(error) return NO;
    
    result = AUGraphConnectNodeInput(self.outputContext->graph,
                                     self.outputContext->converterNodeContext.node,
                                     0,
                                     self.outputContext->mixerNodeContext.node,
                                     0);
    error = checkError(result, @"graph connect converter and mixer error");
    if(error) return NO;
    
    result = AUGraphConnectNodeInput(self.outputContext->graph,
                                     self.outputContext->mixerNodeContext.node,
                                     0,
                                     self.outputContext->outputNodeContext.node,
                                     0);
    error = checkError(result, @"graph connect converter and mixer error");
    if(error) return NO;
    
    result = AUGraphNodeInfo(self.outputContext->graph,
                             self.outputContext->converterNodeContext.node,
                             &converterDescription,
                             &self.outputContext->converterNodeContext.audioUnit);
    error = checkError(result, @"graph get converter audio unit error");
    if(error) return NO;
    
    result = AUGraphNodeInfo(self.outputContext->graph,
                             self.outputContext->mixerNodeContext.node,
                             &mixerDescription,
                             &self.outputContext->mixerNodeContext.audioUnit);
    error = checkError(result, @"graph get minxer audio unit error");
    if(error) return NO;
    
    result = AUGraphNodeInfo(self.outputContext->graph,
                             self.outputContext->outputNodeContext.node,
                             &outputDescription,
                             &self.outputContext->outputNodeContext.audioUnit);
    error = checkError(result, @"graph get output audio unit error");
    if(error) return NO;
    
    AURenderCallbackStruct converterCallback;
    converterCallback.inputProc = renderCallback;
    converterCallback.inputProcRefCon = (__bridge void *)(self);
    result = AUGraphSetNodeInputCallback(self.outputContext->graph,
                                         self.outputContext->converterNodeContext.node,
                                         0,
                                         &converterCallback);
    error = checkError(result, @"graph add converter input callback error");
    if(error) return NO;
    
    result = AudioUnitGetProperty(self.outputContext->outputNodeContext.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input, 0,
                                  &self.outputContext->asbd,
                                  &audioStreamBasicDescriptionSize);
    error = checkError(result, @"get hardware output stream format error");
    if(error) return NO;
    
    if (self.audioSession.sampleRate != self.outputContext->asbd.mSampleRate)
    {
        self.outputContext->asbd.mSampleRate = self.audioSession.sampleRate;
        result = AudioUnitSetProperty(self.outputContext->outputNodeContext.audioUnit,
                                      kAudioUnitProperty_StreamFormat,
                                      kAudioUnitScope_Input,
                                      0,
                                      &self.outputContext->asbd,
                                      audioStreamBasicDescriptionSize);
        error = checkError(result, @"set hardware output stream format error");
        if(error) return NO;
    }

    result = AudioUnitSetProperty(self.outputContext->converterNodeContext.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &self.outputContext->asbd,
                                  sizeof(AudioStreamBasicDescription));
    error = checkError(result, @"graph set converter input format error");
    if(error) return NO;
    
    result = AudioUnitSetProperty(self.outputContext->converterNodeContext.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  0,
                                  &self.outputContext->asbd,
                                  sizeof(AudioStreamBasicDescription));
    error = checkError(result, @"graph set converter output format error");
    if(error) return NO;
    
    result = AudioUnitSetProperty(self.outputContext->mixerNodeContext.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &self.outputContext->asbd,
                                  sizeof(AudioStreamBasicDescription));
    error = checkError(result, @"graph set converter input format error");
    if(error) return NO;
    
    result = AudioUnitSetProperty(self.outputContext->mixerNodeContext.audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  0,
                                  &self.outputContext->asbd,
                                  audioStreamBasicDescriptionSize);
    error = checkError(result, @"graph set converter output format error");
    if(error) return NO;
    
    result = AudioUnitSetProperty(self.outputContext->mixerNodeContext.audioUnit,
                                  kAudioUnitProperty_MaximumFramesPerSlice,
                                  kAudioUnitScope_Global,
                                  0,
                                  &max_frame_size,
                                  sizeof(max_frame_size));
    error = checkError(result, @"graph set mixer max frames per slice size error");
    if(error) return NO;
    
    result = AUGraphInitialize(self.outputContext->graph);
    error = checkError(result, @"graph initialize error");
    if(error) return NO;
    
    return YES;
}

#pragma mark -- rendercallback
static OSStatus renderCallback(void * inRefCon,
                               AudioUnitRenderActionFlags * ioActionFlags,
                               const AudioTimeStamp * inTimeStamp,
                               UInt32 inOutputBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList * ioData)
{
    FFAudioController * controller = (__bridge FFAudioController *)inRefCon;
    return [controller renderFrames:inNumberFrames ioData:ioData];
}

- (OSStatus)renderFrames:(UInt32)numberOfFrames ioData:(AudioBufferList *)ioData
{
    if (!self.registered)
    {
        return noErr;
    }
    
    for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; iBuffer++)
    {
        memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
    }
    
    if (self.playing && self.delegate)
    {
        [self.delegate audioController:self
							outputData:self->_outData
						numberOfFrames:numberOfFrames
					  numberOfChannels:self.numOutputChannels];
        
        UInt32 numBytesPerSample = self.outputContext->asbd.mBitsPerChannel / 8;
        if (numBytesPerSample == 4)
        {
            float zero = 0.0;
            for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; iBuffer++)
            {
                int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
                for (int iChannel = 0; iChannel < thisNumChannels; iChannel++)
                {
                    vDSP_vsadd(self->_outData + iChannel,
                               self.numOutputChannels,
                               &zero,
                               (float *)ioData->mBuffers[iBuffer].mData,
                               thisNumChannels,
                               numberOfFrames);
                }
            }
        }
        else if (numBytesPerSample == 2)
        {
            float scale = (float)INT16_MAX;
            vDSP_vsmul(self->_outData, 1, &scale, self->_outData, 1, numberOfFrames * self.numOutputChannels);
            
            for (int iBuffer = 0; iBuffer < ioData->mNumberBuffers; iBuffer++)
            {
                int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
                for (int iChannel = 0; iChannel < thisNumChannels; iChannel++)
                {
                    vDSP_vfix16(self->_outData + iChannel,
                                self.numOutputChannels,
                                (SInt16 *)ioData->mBuffers[iBuffer].mData + iChannel,
                                thisNumChannels,
                                numberOfFrames);
                }
            }
        }
    }
    
    return noErr;
}

- (void)play
{
    if (!self.playing)
    {
        if ([self registerAudioSession])
        {
            NSError* error;
            OSStatus result = AUGraphStart(self.outputContext->graph);
            error = checkError(result, @"graph start error");
            if (error) return;
            self.playing = YES;
        }
    }
}

- (void)pause
{
    if (self.playing)
    {
        NSError* error;
        OSStatus result = AUGraphStop(self.outputContext->graph);
        error = checkError(result, @"graph stop error");
        if (error) return;
        self.playing = NO;
    }
}

- (float)volume
{
	if (self.registered)
	{
		AudioUnitParameterID param = kMultiChannelMixerParam_Volume;
		AudioUnitParameterValue volume;
		OSStatus result = AudioUnitGetParameter(self.outputContext->mixerNodeContext.audioUnit,
												param,
												kAudioUnitScope_Input,
												0,
												&volume);
		NSError* error = checkError(result, @"graph set mixer volum error");
		if(error)
		{
			return 0.0f;
		}
		else
		{
			return volume;
		}
	}

	return 1.f;
}

- (void)setVolume:(float)volume
{
    if (self.registered)
    {
        AudioUnitParameterID param = kMultiChannelMixerParam_Volume;
        OSStatus result = AudioUnitSetParameter(self.outputContext->mixerNodeContext.audioUnit,
                                                param,
                                                kAudioUnitScope_Input,
                                                0,
                                                volume,
                                                0);
        NSError* error = checkError(result, @"graph set mixer volum error");
        if(error) return;
    }
}

- (Float64)sampleRate
{
    if (!self.registered)
    {
        return 0;
    }
    
    Float64 number = self.outputContext->asbd.mSampleRate;
    if (number > 0)
    {
        return number;
    }
    
    return (Float64)self.audioSession.sampleRate;
}

- (UInt32)numOutputChannels
{
    if (!self.registered)
    {
        return 0;
    }
    
    UInt32 number = self.outputContext->asbd.mChannelsPerFrame;
    if (number > 0)
    {
        return number;
    }
    
    return (UInt32)self.audioSession.outputNumberOfChannels;
}

- (void)dealloc
{
    [self unregisterAudioSession];
    if (self->_outData)
    {
        free(self->_outData);
        self->_outData = NULL;
    }
    
    self.playing = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
	LOG_DEBUG(@"%@ release...",[self class]);
}

#pragma mark -- interruptionhandler
- (void)audioSessionInterruptionHandler:(NSNotification *)notification
{
    AVAudioSessionInterruptionType avType = [[notification.userInfo objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];

    if (avType == AVAudioSessionInterruptionTypeEnded)
    {
        //end
		LOG_INFO(@"AVAudioSessionInterruptionTypeEnded");
    }

    id avOption = [notification.userInfo objectForKey:AVAudioSessionInterruptionOptionKey];
    if (avOption)
    {
        AVAudioSessionInterruptionOptions temp = [avOption unsignedIntegerValue];
        if (temp == AVAudioSessionInterruptionOptionShouldResume)
        {
            //resume
			LOG_INFO(@"AVAudioSessionInterruptionOptionShouldResume");
        }
    }
}

- (void)audioSessionRouteChangeHandler:(NSNotification *)notification
{
    AVAudioSessionRouteChangeReason avReason = [[notification.userInfo objectForKey:AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    switch (avReason)
    {
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
        {
			LOG_INFO(@"AVAudioSessionRouteChangeReasonOldDeviceUnavailable");
        }
            break;
        default:
            break;
    }
}

static NSError * checkError(OSStatus result, NSString * domain)
{
    if (result == noErr) return nil;
    NSError * error = [NSError errorWithDomain:domain code:result userInfo:nil];
    LOG_ERROR(@"%@",error);
    
    return error;
}

@end
