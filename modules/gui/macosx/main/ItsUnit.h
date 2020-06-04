

#import <Foundation/Foundation.h>
#import "playlist/VLCPlaylistController.h"
#import "windows/video/VLCVoutView.h"
#import "windows/VLCOpenInputMetadata.h"



@interface ItsUnit : NSObject

-(instancetype)initWithPlaylist:(VLCPlaylistController*)playlistController andVideoView:(VLCVoutView*)videoView;


-(void)openTutorialVideo;
-(void)addSyncFolder;
-(void)shareVideo;
-(void)playVideo;
-(void)pauseVideo;
-(void)stopVideo:(bool)async;
-(void)connectToStreamWithInput:(VLCOpenInputMetadata*)inputData andHash:(NSString*)hash;
-(void)onMediaItemChanged;
-(bool)getItsStreaming;

@end

