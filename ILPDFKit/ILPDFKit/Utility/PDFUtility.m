//  Created by Derek Blair on 2/24/2014.
//  Copyright (c) 2014 iwelabs. All rights reserved.

#import "PDFUtility.h"
#import "PDFObject.h"
#import "PDFDocument.h"
#import <zlib.h>

@implementation PDFUtility

static PDFUtility* _sharedPDFUtility = nil;

#pragma mark - NSObject

-(void)dealloc
{
 
    _sharedPDFUtility= nil;
    [super dealloc];
}

-(id)init
{
    self = [super init];
    if(self!=nil)
    {
    }
    
    return self;
}

+(id)alloc
{
	@synchronized([PDFUtility class])
	{
		NSAssert(_sharedPDFUtility == nil, @"Attempted to allocate a second instance of a PDFUtility");
		_sharedPDFUtility = [super alloc];
		return _sharedPDFUtility;
	}
	return nil;
}

#pragma mark - Shared Instance

+(PDFUtility*)sharedPDFUtility
{
	@synchronized([PDFUtility class])
	{
		if(!_sharedPDFUtility)
			[[self alloc] init];
        
		return _sharedPDFUtility;
	}
	return nil;
}


#pragma mark - Utility Functions


+(CGContextRef)outputPDFContextCreate:(const CGRect *)inMediaBox Path:(CFStringRef)path
{
    CGContextRef outContext = NULL;
    CFURLRef url;
    url = CFURLCreateWithFileSystemPath(NULL,path,kCFURLPOSIXPathStyle,false);
    if (url != NULL)
    {
        outContext = CGPDFContextCreateWithURL(url,inMediaBox,NULL);
        CFRelease(url);
        
    }
    return outContext;
}

+(CGPDFDocumentRef)createPDFDocumentRefFromData:(NSData*)data
{
    CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((CFDataRef)data);
    CGPDFDocumentRef pdf = CGPDFDocumentCreateWithProvider(dataProvider);
    CGDataProviderRelease(dataProvider);
    return pdf;
}

+(CGPDFDocumentRef)createPDFDocumentRefFromResource:(NSString*)name
{
    NSString *pathToPdfDoc = [[NSBundle mainBundle] pathForResource:name ofType:@"pdf"];
    NSURL *url = [NSURL fileURLWithPath:pathToPdfDoc];
    CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL((CFURLRef)url);
    return pdf;
}

+(CGPDFDocumentRef)createPDFDocumentRefFromPath:(NSString*)pathToPdfDoc
{
    NSURL *url = [NSURL fileURLWithPath:pathToPdfDoc];
    CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL((CFURLRef)url);
    return pdf;
}


+(NSString*)pdfEncodedString:(NSString*)stringToEncode
{
    if([stringToEncode rangeOfString:@"%"].location!=NSNotFound)return NULL;
    CFStringRef encodedStr= CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef)stringToEncode,NULL,(CFStringRef)@"!*()@$/?#[] \t\n\r",kCFStringEncodingUTF8);
    NSString* ret = [[[NSString alloc] initWithString:(NSString*)encodedStr] autorelease];
    CFRelease(encodedStr);
    return [ret stringByReplacingOccurrencesOfString:@"%" withString:@"#"];
}


+(NSString*)pdfObjectRepresentationFrom:(id)obj
{
    NSString* objRepresentation = nil;
    
    if([obj isKindOfClass:[NSString class]])
    {
        
        if([obj rangeOfString:@"ioref"].location!=NSNotFound)
        {
            NSArray* tokens = [obj componentsSeparatedByString:@","];
            objRepresentation = [NSString stringWithFormat:@"%u %u R",[[tokens objectAtIndex:0] integerValue],[[tokens objectAtIndex:1] integerValue]];
            
        }
        else if([obj isName])
        {
            objRepresentation = [NSString stringWithFormat:@"/%@",[PDFUtility pdfEncodedString:obj]];
        }
        else
        {
            objRepresentation = [NSString stringWithFormat:@"(%@)",obj];
        }
    }
    else if([obj isKindOfClass:[NSData class]])
    {
        NSString* temp = [[NSString alloc] initWithData:obj encoding:NSUTF8StringEncoding];
            objRepresentation = [NSString stringWithFormat:@"<%@>",temp];
        [temp release];
    }
    else if([obj isKindOfClass:[NSNumber class]])
    {
        if (strcmp([obj objCType], @encode(BOOL)) == 0)
        {
            if([obj boolValue])objRepresentation = @"true";
            else objRepresentation = @"false";
        }
        else objRepresentation = [NSString stringWithFormat:@"%@",obj];
    }
    else if([obj isKindOfClass:[PDFObject class]])
    {
        objRepresentation = [obj pdfFileRepresentation];
    }
    else
    {
        objRepresentation = @"null";
    }
    
    return objRepresentation;

}

+(NSCharacterSet*)whiteSpaceCharacterSet
{
    NSMutableCharacterSet* ret = [NSMutableCharacterSet characterSetWithRange:NSMakeRange(0, 1)];
    [ret addCharactersInRange:NSMakeRange(9, 2)];
    [ret addCharactersInRange:NSMakeRange(12, 2)];
    [ret addCharactersInRange:NSMakeRange(32, 1)];
    
    return ret;
}


+(NSString*)stringReplacingWhiteSpaceWithSingleSpace:(NSString*)str
{

    NSString* ret = str;
    NSUInteger c;
    
    while((c=[ret rangeOfString:@"%"].location)!= NSNotFound)
    {
        
        NSUInteger end = c;
        while([ret characterAtIndex:end]!=13 && [ret characterAtIndex:end]!=10)end++;
        NSString* find = [ret substringWithRange:NSMakeRange(c, end-c)];
        ret = [ret stringByReplacingOccurrencesOfString:find withString:@" "];
    }
    
    ret = [str stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:@" "];
    ret = [ret stringByReplacingCharactersInRange:NSMakeRange(9, 2) withString:@" "];
    ret = [ret stringByReplacingCharactersInRange:NSMakeRange(12, 2) withString:@" "];
    
    

    while ([ret rangeOfString:@"  "].location != NSNotFound)
    {
        ret = [ret stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    }
    
    return ret;
}


+(NSString*)urlEncodeString:(NSString*)str
{
    if(str == nil)return nil;
    if([str isKindOfClass:[NSString class]]== NO)return str;
    if([str length]==0)return str;
    
    CFStringRef encodedStr= CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef)str,NULL,(CFStringRef)@"!*()@,$^~/?%#[]'\" \t\n\r",kCFStringEncodingUTF8);
    
    NSString* ret = [[[NSString alloc] initWithString:(NSString*)encodedStr] autorelease];
    
    CFRelease(encodedStr);
    
    
    return ret;
}

+(NSString*)decodeURLEncodedString:(NSString*)str
{
    if(str == nil)return nil;
    if([str isKindOfClass:[NSString class]]== NO)return str;
    if([str length]==0)return str;
    
    CFStringRef decodedStr= CFURLCreateStringByReplacingPercentEscapes(NULL,(CFStringRef)str,CFSTR(""));
    
    NSString* ret = [[[NSString alloc] initWithString:(NSString*)decodedStr] autorelease];
    
    CFRelease(decodedStr);
    
    
    return ret;
}

+(NSString*)urlEncodeStringXML:(NSString*)str
{
    if(str == nil)return nil;
    if([str isKindOfClass:[NSString class]]== NO)return str;
    if([str length]==0)return str;
    
    return [[str stringByReplacingOccurrencesOfString:@"<" withString:@"&#60;"] stringByReplacingOccurrencesOfString:@">" withString:@"&#62;"] ;
    
}

+(NSData *)gzipInflate:(NSData*)data
{
    if ([data length] == 0) return data;
    
    unsigned full_length = [data length];
    unsigned half_length = [data length] / 2;
    
    NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
    BOOL done = NO;
    int status;
    
    z_stream strm;
    strm.next_in = (Bytef *)[data bytes];
    strm.avail_in = [data length];
    strm.total_out = 0;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    
    if (inflateInit2(&strm, (15+32)) != Z_OK) return nil;
    while (!done)
    {
        // Make sure we have enough room and reset the lengths.
        if (strm.total_out >= [decompressed length])
            [decompressed increaseLengthBy: half_length];
        strm.next_out = [decompressed mutableBytes] + strm.total_out;
        strm.avail_out = [decompressed length] - strm.total_out;
        
        // Inflate another chunk.
        status = inflate (&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END) done = YES;
        else if (status != Z_OK) break;
    }
    if (inflateEnd (&strm) != Z_OK) return nil;
    
    // Set real length.
    if (done)
    {
        [decompressed setLength: strm.total_out];
        return [NSData dataWithData: decompressed];
    }
    else return nil;
}



+ (NSData *)zlibInflate:(NSData*)data
{
    if ([data length] == 0) return data;
    
    unsigned full_length = [data length];
    unsigned half_length = [data length] / 2;
    
    NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
    BOOL done = NO;
    int status;
    
    z_stream strm;
    strm.next_in = (Bytef *)[data bytes];
    strm.avail_in = [data length];
    strm.total_out = 0;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    
    if (inflateInit (&strm) != Z_OK) return nil;
    
    while (!done)
    {
        // Make sure we have enough room and reset the lengths.
        if (strm.total_out >= [decompressed length])
            [decompressed increaseLengthBy: half_length];
        strm.next_out = [decompressed mutableBytes] + strm.total_out;
        strm.avail_out = [decompressed length] - strm.total_out;
        
        // Inflate another chunk.
        status = inflate (&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END) done = YES;
        else if (status != Z_OK) break;
    }
    if (inflateEnd (&strm) != Z_OK) return nil;
    
    // Set real length.
    if (done)
    {
        [decompressed setLength: strm.total_out];
        return [NSData dataWithData: decompressed];
    }
    else return nil;
}


+ (NSData *)zlibDeflate:(NSData*)data
{
	if ([data length] == 0) return data;
    
	z_stream strm;
    
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	strm.opaque = Z_NULL;
	strm.total_out = 0;
	strm.next_in=(Bytef *)[data bytes];
	strm.avail_in = (uInt)[data length];
    
	// Compresssion Levels:
	//   Z_NO_COMPRESSION
	//   Z_BEST_SPEED
	//   Z_BEST_COMPRESSION
	//   Z_DEFAULT_COMPRESSION
    
	if (deflateInit(&strm, Z_DEFAULT_COMPRESSION) != Z_OK) return nil;
    
	NSMutableData *compressed = [NSMutableData dataWithLength:16384];  // 16K chuncks for expansion
    
	do {
        
		if (strm.total_out >= [compressed length])
			[compressed increaseLengthBy: 16384];
        
		strm.next_out = [compressed mutableBytes] + strm.total_out;
		strm.avail_out = (uInt)([compressed length] - strm.total_out);
        
		deflate(&strm, Z_FINISH);
        
	} while (strm.avail_out == 0);
    
	deflateEnd(&strm);
    
	[compressed setLength: strm.total_out];
	return [NSData dataWithData: compressed];
}


@end
