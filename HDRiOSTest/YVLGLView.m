//
//  YVLGLView.m
//  HDRiOSTest
//
//  Created by ashawn on 2021/9/26.
//

#import "YVLGLView.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

#define GLES_SILENCE_DEPRECATION
//方便定义shader字符串的宏
#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

//顶点着色器
NSString *const nv12vertexShaderString = SHADER_STRING
(#version 300 es
 layout(location = 0) in vec4 vertexPosition;
 layout(location = 1) in vec2 textureCoords;
 //attribute 关键字用来描述传入shader的变量
// attribute vec4 vertexPosition; //传入的顶点坐标
// attribute vec2 textureCoords;//要获取的纹理坐标
 //传给片段着色器参数
 out  vec2 textureCoordsOut;
 void main(void) {
     gl_Position = vertexPosition; // gl_Position是vertex shader的内建变量，gl_Position中的顶点值最终输出到渲染管线中
     textureCoordsOut = textureCoords;
 }
 );
//片段着色器
NSString *const nv12fragmentShaderString = SHADER_STRING
(#version 300 es
 
 in highp vec2 textureCoordsOut;
 
 uniform highp usampler2D y_texture;
 uniform highp usampler2D uv_texture;
 
 layout(location = 0) out highp vec4 fragColor;
 
 void main(void) {
    
     highp float y = float(texture(y_texture, textureCoordsOut).r) / 65535.0 - 64.0/1023.0;//texture2D(y_texture, textureCoordsOut).r;
     highp float u = float(texture(uv_texture, textureCoordsOut).r) / 65535.0 - 0.5;
     highp float v = float(texture(uv_texture, textureCoordsOut).g) / 65535.0 - 0.5;

     highp float r = 1.164383561643836 * y + 1.678674107143 * v;
     highp float g = 1.164383561643836 * y - 0.127007098661 * u - 0.440987687946 * v;
     highp float b = 1.164383561643836 * y + 2.141772321429 * u;
    
    
    highp vec3 color = vec3(r,g,b);
    
    if(color.x > 1.0 || color.y > 1.0 || color.z > 1.0)
    {
        fragColor = vec4(1.0,1.0,0.0,1.0);
    }
    else
    {
        fragColor = vec4(color,1.0);
    }

 }
 );

//片段着色器
NSString *const rgbafragmentShaderString = SHADER_STRING
(#version 300 es
 
 in highp vec2 textureCoordsOut;
 
 uniform highp sampler2D rgba_texture;
 
 layout(location = 0) out highp vec4 fragColor;
 
 void main(void) {
    
    fragColor = texture(rgba_texture, textureCoordsOut);
    
 }
 );

@interface YVLGLView ()
{
    GLuint _renderBuffer;
    GLuint _framebuffer;
    
    GLuint _yTexture;
    GLuint _uvTexture;
    
    //着色器程序
    GLuint _glprogram;
    //记录renderbuffer的宽高
    GLint           _backingWidth;
    GLint           _backingHeight;
    
    
    dispatch_queue_t _renderQueue;
    
    //纹理参数
    GLint _y_texture;
    GLint _uv_texture;
    //顶点参数
    GLint _vertexPosition;
    //纹理坐标参数
    GLint _textureCoords;
    
}
@property(nonatomic,strong)CAEAGLLayer*eaglLayer;
@property(nonatomic,strong)EAGLContext*context;

@end

@implementation YVLGLView

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self commonInit];
    }
    
    return self;
}
-(instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self commonInit];
    }
    return self;
}
+(Class)layerClass
{
    return [CAEAGLLayer class];
}

-(void)commonInit{
    
    _renderQueue = dispatch_queue_create("renderQueue", DISPATCH_QUEUE_SERIAL);
    
    
    [self prepareLayer];
    dispatch_sync(_renderQueue, ^{
        [self prepareContext];
        [self prepareShader];
        [self prepareRenderBuffer];
        [self prepareFrameBuffer];
        
//        [self createFrameBufferObjectAndRenderTarget:self.context OutputSize:CGSizeMake(3840, 2160)];
    });
    
    
}

- (void)dealloc
{
    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    
    if (_renderBuffer) {
        glDeleteRenderbuffers(1, &_renderBuffer);
        _renderBuffer = 0;
    }
    
    if (_glprogram) {
        glDeleteProgram(_glprogram);
        _glprogram = 0;
    }
    
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    _context = nil;
}

#pragma mark - private methods
-(void)prepareLayer
{
    self.eaglLayer = (CAEAGLLayer*)self.layer;
    self.eaglLayer.opaque = YES;
    self.eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
    
}

-(void)prepareContext
{
    self.context = [[EAGLContext alloc]initWithAPI:kEAGLRenderingAPIOpenGLES3];
    [EAGLContext setCurrentContext:self.context];
}

-(void)prepareRenderBuffer{
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    //调用这个方法来创建一块空间用于存储缓冲数据，替代了glRenderbufferStorage
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.eaglLayer];
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
}

-(void)prepareFrameBuffer
{
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    
    //设置gl渲染窗口大小
    glViewport(0, 0, _backingWidth, _backingHeight);
    //附加之前的_renderBuffer
    //GL_COLOR_ATTACHMENT0指定第一个颜色缓冲区附着点
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, _renderBuffer);
    
    glGenTextures(1, &_yTexture);
   
    glGenTextures(1, &_uvTexture);
}

-(void)prepareShader
{
    //创建顶点着色器
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    
    const GLchar* const vertexShaderSource =  (GLchar*)[nv12vertexShaderString UTF8String];
    GLint vertexShaderLength = (GLint)[nv12vertexShaderString length];
    //读取shader字符串
    glShaderSource(vertexShader, 1, &vertexShaderSource, &vertexShaderLength);
    //编译shader
    glCompileShader(vertexShader);
    
    GLint logLength;
    glGetShaderiv(vertexShader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(vertexShader, logLength, &logLength, log);
        NSLog(@"%s\n",log);
        free(log);
    }
    
    //创建片元着色器
    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    const GLchar* const fragmentShaderSource = (GLchar*)[nv12fragmentShaderString UTF8String];
    GLint fragmentShaderLength = (GLint)[nv12fragmentShaderString length];
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, &fragmentShaderLength);
    glCompileShader(fragmentShader);
    
    glGetShaderiv(fragmentShader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(fragmentShader, logLength, &logLength, log);
        NSLog(@"%s\n",log);
        free(log);
    }
    
    //创建glprogram
    _glprogram = glCreateProgram();
    
    //绑定shader
    glAttachShader(_glprogram, vertexShader);
    glAttachShader(_glprogram, fragmentShader);
    //链接program
    glLinkProgram(_glprogram);
    
    //选择程序对象为当前使用的程序，类似setCurrentContext
    glUseProgram(_glprogram);
    
    //获取并保存参数位置
    _y_texture = glGetUniformLocation(_glprogram, "y_texture");
    _uv_texture = glGetUniformLocation(_glprogram, "uv_texture");
    _vertexPosition = glGetAttribLocation(_glprogram, "vertexPosition");
    _textureCoords = glGetAttribLocation(_glprogram, "textureCoords");
    
    
    //使参数可见
    glEnableVertexAttribArray(_vertexPosition);
    glEnableVertexAttribArray(_textureCoords);
}

-(void)renderWithYBuffer:(uint16_t*)YData UVBuffer:(uint16_t*)UVData width:(int)width height:(int)height
{
    dispatch_sync(_renderQueue, ^{
        //检查context
        if ([EAGLContext currentContext] != self.context)
        {
            [EAGLContext setCurrentContext:self.context];
        }
        
        GLenum err;
        err = glGetError();
        GLfloat vertices[] = {
            -1,1,
            1,1,
            -1,-1,
            1,-1,
            
        };
        GLfloat textCoord[] = {
            0,1,
            1,1,
            0,0,
            1,0,
        };
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, _yTexture);
        //确定采样器对应的哪个纹理，由于只使用一个，所以这句话可以不写
        glUniform1i(_y_texture,0);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_R16UI, width, height, 0, GL_RED_INTEGER, GL_UNSIGNED_SHORT, YData);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        
        glActiveTexture(GL_TEXTURE1);

        glBindTexture(GL_TEXTURE_2D, _uvTexture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RG16UI, width/2, height/2, 0, GL_RG_INTEGER, GL_UNSIGNED_SHORT, UVData);
        glUniform1i(_uv_texture,1);
        
        
        //设置一些边缘的处理
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        
        glVertexAttribPointer(_vertexPosition, 2, GL_FLOAT, GL_FALSE, 0, vertices);
        glVertexAttribPointer(_textureCoords, 2, GL_FLOAT, GL_FALSE,0, textCoord);
        
        //清屏为白色
        glClearColor(1.0, 1.0, 1.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        //EACAGLContext 渲染OpenGL绘制好的图像到EACAGLLayer
        [_context presentRenderbuffer:GL_RENDERBUFFER];
    });
}

@end
