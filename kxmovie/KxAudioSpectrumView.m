//
//  KxAudioSpectrumView.m
//  kxmovie
//
//  Created by Kolyvan on 19.12.12.
//
//

#import "KxAudioSpectrumView.h"
#import <Accelerate/Accelerate.h>

//from CoreAudio/PublicUtility/CABitOperations.h
// count the leading zeros in a word
// Metrowerks Codewarrior. powerpc native count leading zeros instruction:
// I think it's safe to remove this ...
//#define CountLeadingZeroes(x)  ((int)__cntlzw((unsigned int)x))

static UInt32 CountLeadingZeroes(UInt32 arg)
{
    // GNUC / LLVM has a builtin
#if defined(__GNUC__)
    // on llvm and clang the result is defined for 0
#if (TARGET_CPU_X86 || TARGET_CPU_X86_64) && !defined(__llvm__)
    if (arg == 0) return 32;
#endif  // TARGET_CPU_X86 || TARGET_CPU_X86_64
    return __builtin_clz(arg);
#elif TARGET_OS_WIN32
    UInt32 tmp;
    __asm{
        bsr eax, arg
        mov ecx, 63
        cmovz eax, ecx
        xor eax, 31
        mov tmp, eax    // this moves the result in tmp to return.
    }
    return tmp;
#else
#error "Unsupported architecture"
#endif  // defined(__GNUC__)
}

// base 2 log of next power of two greater or equal to x
static UInt32 Log2Ceil(UInt32 x)
{
    return 32 - CountLeadingZeroes(x - 1);
}

/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////

@interface KxAudioSpectrumView()
@property (readwrite, strong) NSData *spectrum;
@end

@implementation KxAudioSpectrumView {

    FFTSetup            _fftSetup;
    DSPSplitComplex     _dspSplitComplex;
    NSUInteger          _log2FFTSize;
    NSUInteger          _fftSize;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {

    }
    return self;
}

- (void) dealloc
{
    if (_fftSetup)
        vDSP_destroy_fftsetup(_fftSetup), _fftSetup = NULL;
    
    if (_dspSplitComplex.realp)
        free(_dspSplitComplex.realp), _dspSplitComplex.realp = NULL;
    
    if (_dspSplitComplex.imagp)
        free(_dspSplitComplex.imagp), _dspSplitComplex.imagp = NULL;    
}

- (void) renderSamples: (float *) samples
             numFrames: (UInt32) numFrames
           numChannels: (UInt32) numChannels
{
    const NSUInteger numBytes = numFrames * sizeof(float);
    
    NSMutableData *data = [NSMutableData dataWithLength:numBytes];
    
    // handle only single (left) channel
    // TODO: convert stereo to mono or handle stereo (left and right channel separately)
    
    float zero = 0;
    vDSP_vsadd(samples, numChannels, &zero, data.mutableBytes, 1, numFrames);    
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        [self refreshSpectrum:data];
        [self performSelectorOnMainThread:@selector(setNeedsDisplay) withObject:nil waitUntilDone:NO];
    });
}

- (void) refreshSpectrum: (NSMutableData *) samples
{
    const NSUInteger numSamples = samples.length / sizeof(float);
    const NSUInteger log2FFTSize = Log2Ceil(numSamples);
    const NSUInteger fftSize = numSamples >> 1;
    
    if (!_fftSetup ||
        log2FFTSize != _log2FFTSize) {
        
        NSLog(@">>> SETUP FFT %d %d %d", numSamples, log2FFTSize, fftSize);
        
        _log2FFTSize = log2FFTSize;
        _fftSetup = vDSP_create_fftsetup(_log2FFTSize, FFT_RADIX2);
        if (!_fftSetup)
            return;
    }
    
    if (!_dspSplitComplex.realp ||
        !_dspSplitComplex.imagp ||
        _fftSize != fftSize) {
        
        _fftSize = fftSize;
        _dspSplitComplex.realp = reallocf(_dspSplitComplex.realp, _fftSize * sizeof(float));
        if (!_dspSplitComplex.realp)
            return;
        _dspSplitComplex.imagp = reallocf(_dspSplitComplex.imagp, _fftSize * sizeof(float));
        if (!_dspSplitComplex.imagp)
            return;
    }
    
    samples.length = (fftSize - 1) * sizeof(float);
    
    vDSP_ctoz(samples.bytes, 2, &_dspSplitComplex, 1, _fftSize);
    vDSP_fft_zrip(_fftSetup, &_dspSplitComplex, 1, _log2FFTSize, FFT_FORWARD);        
    vDSP_zvmags(&_dspSplitComplex, 1, _dspSplitComplex.realp, 1, _fftSize);
    
    // in decibel
    // skip first entry 
    // real[0] holds the average value of all the points in the time domain signal
    // imag[0] Nyquist frequence
    
    float scalar = 1.0;
    vDSP_vdbcon(_dspSplitComplex.realp + 1, 1, &scalar, samples.mutableBytes, 1, _fftSize - 1, 1);
    
    self.spectrum = samples;
}

- (void)drawRect:(CGRect)r
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    const CGRect bounds = self.bounds;
    
    [[UIColor blackColor] set];
	CGContextFillRect(context, bounds);
    
    NSData *data = self.spectrum;
    
    if (data.length) {
        
        const float MINDB = -40.0;
        const float MAXDB = 130.0;
        
        const NSUInteger numSamples = data.length / sizeof(float);
        const float *samples = (float *)data.bytes;
        
        const CGFloat X = bounds.origin.x;
        const CGFloat Y = bounds.origin.y + bounds.size.height;
        const CGFloat dX = bounds.size.width / numSamples;
        const CGFloat dY = bounds.size.height / (MAXDB - MINDB);
        
        [[UIColor orangeColor] set];
        
        for (NSUInteger i = 0; i < numSamples; ++i) {
            
            const float dB = samples[i];
            const float ddB = dB < MINDB ? MINDB : dB > MAXDB ? MAXDB : dB;
            const float H = (ddB - MINDB) * dY;
            const CGRect rc = CGRectMake(X + i * dX, Y, dX, -H);
            CGContextFillRect(context, rc);
        }
    }
}

@end
