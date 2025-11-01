//
//  NSURL+fileRef.m
//  GRPCLib
//
//  Created by Frederic BOLTZ on 01/11/2025.
//

#import "NSURL+fileRef.h"

NS_ASSUME_NONNULL_BEGIN

NSString* getFileRefURL(NSURL* url) {
	url = [url fileReferenceURL];
		
	return url.absoluteString;
}

NS_ASSUME_NONNULL_END
