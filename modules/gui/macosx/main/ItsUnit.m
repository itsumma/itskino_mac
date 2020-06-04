

#import "ItsUnit.h"
#import "main/VLCMain.h"
#import "playlist/VLCPlayerController.h"
//#import "windows/VLCOpenInputMetadata.h"
#import "extensions/NSString+Helpers.h"


@interface ItsUnit()
{
	NSString *_itsTutorialUrl, *_itsApiUrl, *_itsUserUid, *_itsStreamHash, *_itsStreamToDelete, *_wentWrongString, *_itsSyncFolder;
	bool _itsInitStream, _itsStreaming;
	int _progressIndicatorSize;
	VLCPlaylistController *_playlistController;
	VLCPlayerController *_playerController;
	NSProgressIndicator *_itsProgressIndicator;
	VLCVoutView* _videoView;
	
}
-(void)initItsUserUid;
-(void)setProgressIndicator;
-(void)removeProgressIndicator;
-(bool)showItsAlert:(NSString*)infoText andSyncFolderFlag:(bool)syncFolder;
-(void)handleShareRequest;
-(void)handlePlayRequest;
-(void)handlePauseRequest;
-(void)handleStopRequest:(bool)async withHash:(NSString*)hashToRemove;
-(void)handleConnectRequest:(VLCOpenInputMetadata*)inputData;
-(bool)checkLocalFile:(NSString*)file;
@end

@implementation ItsUnit


//public

-(instancetype)initWithPlaylist:(VLCPlaylistController *)playlistController andVideoView:(VLCVoutView *)videoView
{
	self = [super init];
	if(self){
		//_itsApiUrl = @"http://0.0.0.0:8000/api/";
		_itsApiUrl = @"https://itskino.ru/api/";
		_itsTutorialUrl = @"https://www.youtube.com/watch?v=kWPRuwTAZic&feature=youtu.be";
		_wentWrongString = @"Something went wrong. Please try again later";
		_itsUserUid = @"";
		_itsStreamHash = @"";
		_itsStreamToDelete = @"";
		_itsStreaming = false;
		_itsInitStream = false;
		_itsProgressIndicator = nil;
		_playlistController = playlistController;
		_playerController = _playlistController.playerController;
		_videoView = videoView;
		_progressIndicatorSize = 70;
		[self initItsUserUid];
	}
	return self;
}

-(void)shareVideo
{
	if(_itsStreaming){
		NSString *infoStr = @"Stream is running. Please stop current stream to init a new one";
		[self showItsAlert:infoStr andSyncFolderFlag:false];
		return;
	}
		
	[_playerController pause];
	[self handleShareRequest];
}

-(void)playVideo{
	 [self handlePlayRequest];
}
-(void)pauseVideo{
	[self handlePauseRequest];
}
-(void)stopVideo:(bool)async
{
	_itsStreaming = false;
	[self handleStopRequest:async withHash:_itsStreamHash];
}

-(void)openTutorialVideo
{
	VLCOpenInputMetadata *inputMetadata = [[VLCOpenInputMetadata alloc] init];
	inputMetadata.MRLString = _itsTutorialUrl;
	inputMetadata.itemName = @"Tutorial";
	[_playlistController addPlaylistItems:@[inputMetadata]];
}

-(void)connectToStreamWithInput:(VLCOpenInputMetadata*)inputData andHash:(NSString*)hash
{
	if(_itsStreaming) _itsStreamToDelete = _itsStreamHash;
	_itsStreamHash = hash;
					
	if([_itsStreamHash isEqualToString:_itsStreamToDelete]){
		NSString *infoStr = @"You are trying to restart playing stream";
		[self showItsAlert:infoStr andSyncFolderFlag:false];
		return;
	}
	
	[self handleConnectRequest:inputData];
}

-(void)onMediaItemChanged
{
	enum vlc_player_state state = [_playerController playerState];
	if(_itsStreaming){ // remove current stream if exists
		_itsStreaming = false;
		NSString *hash;
		if([_itsStreamToDelete length] > 0){
			hash = _itsStreamToDelete;
			_itsStreamToDelete = @"";
		}else{
			hash = _itsStreamHash;
		}
		[self handleStopRequest:true withHash:hash];
	}
	
	if (_itsInitStream) { // init new stream
		dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 1);
		dispatch_after(delay, dispatch_get_main_queue(), ^(void){
			[_playerController pause];
			_itsInitStream = false;
			_itsStreaming = true;
		});
	}
}

-(bool)getItsStreaming
{
	return _itsStreaming;
}


// private

-(void)initItsUserUid
{
	NSString *savedUid = [[NSUserDefaults standardUserDefaults] stringForKey:@"itsUid"];
	if(!savedUid || [savedUid length] == 0){
		NSString *uid =  [[NSUUID UUID] UUIDString];
		[[NSUserDefaults standardUserDefaults] setObject:uid forKey:@"itsUid"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		_itsUserUid = uid;
		[self openTutorialVideo];
	}else{
		_itsUserUid = savedUid;
	}
}

-(void)setProgressIndicator
{
	int x = (_videoView.frame.size.width / 2) - (_progressIndicatorSize / 2);
	int y = (_videoView.frame.size.height / 2) - (_progressIndicatorSize / 2);
	_itsProgressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(x, y, _progressIndicatorSize, _progressIndicatorSize)];

	[_itsProgressIndicator setStyle:NSProgressIndicatorSpinningStyle];
	[_itsProgressIndicator startAnimation:nil];
	[_videoView addSubview:_itsProgressIndicator];
}

-(void)removeProgressIndicator
{
	[_itsProgressIndicator removeFromSuperview];
	_itsProgressIndicator = nil;
}

-(bool)showItsAlert:(NSString*)infoText andSyncFolderFlag:(bool)syncFolder
{
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setMessageText:@"ITSKino"];
	[alert setInformativeText:_NS([infoText UTF8String])];
	[alert addButtonWithTitle:@"Ok"];
	if(syncFolder) [alert addButtonWithTitle:@"Cancel"];
	//[alert runModal];
	NSModalResponse responseTag = [alert runModal];
	if(!syncFolder) return true;
	
	if (responseTag == NSAlertFirstButtonReturn) [self addSyncFolder];
	else return false;
	
	return true;
}

-(void)addSyncFolder
{
	//NSString *savedValue = [[NSUserDefaults standardUserDefaults] stringForKey:@"itsSyncFolder"];
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setAllowsMultipleSelection: NO];
	[openPanel setCanChooseFiles: NO];
	[openPanel setCanChooseDirectories: YES];
	[openPanel setTitle: _NS("Open File")];
	[openPanel setPrompt: _NS("Open")];

	if ([openPanel runModal] == NSModalResponseOK) {
		NSArray *urls = [openPanel URLs];
		NSURL *url = urls[0];
		[[NSUserDefaults standardUserDefaults] setObject:url.absoluteString forKey:@"itsSyncFolder"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		_itsSyncFolder = url.absoluteString;
	}
}

-(void)handleShareRequest{
	enum vlc_player_state state = _playerController.playerState;
	NSURL *mrl =  _playerController.URLOfCurrentMediaItem;
	int duration = floor(_playerController.durationOfCurrentMediaItem / 1000000);
	int time = floor(_playerController.time / 1000000);
	
	if((!mrl || [mrl.absoluteString length] == 0) || (state != VLC_PLAYER_STATE_PAUSED && state != VLC_PLAYER_STATE_PLAYING)){
		NSString *infoStr = @"No video to share";
		[self showItsAlert:infoStr andSyncFolderFlag:false];
		return;
	}
	
	[self setProgressIndicator];

	dispatch_async(dispatch_get_main_queue(), ^(void){
		NSDictionary *tmp = [[NSDictionary alloc] initWithObjectsAndKeys:
		_itsUserUid, @"userGuid",
		mrl.absoluteString, @"source",
		[NSString stringWithFormat:@"%i", duration] , @"length",
		[NSString stringWithFormat:@"%i", time], @"startTime",
		nil];

		NSError *err;
		NSData *postData = [NSJSONSerialization dataWithJSONObject:tmp options:0 error:&err];
		NSString *apiUrl =  [NSString stringWithFormat:@"%@%@", _itsApiUrl, @"stream/create"];
		
		NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:apiUrl]];
		[urlRequest setHTTPMethod:@"POST"];
		[urlRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
		[urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
		
		[urlRequest setHTTPBody:postData];
		NSURLResponse * response = nil;
		NSError * error = nil;
		NSData * data = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
		[self removeProgressIndicator];
		
		if(!response){
			_itsStreaming = false;
			[self showItsAlert:_wentWrongString andSyncFolderFlag:false];
			return;
		}
		
		NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
		NSString *status = [responseDictionary valueForKey:@"status"];
		if(status && [status isEqualToString:@"OK"])
		{
			_itsStreaming = true;
			_itsStreamHash =  [responseDictionary valueForKey:@"hash"];
			NSString *link = [responseDictionary valueForKey:@"link"];
			//NSString *hash = [responseDictionary valueForKey:@"hash"];
			NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
			[pasteBoard clearContents];
			[pasteBoard setString:link forType:NSStringPboardType];
			
			NSString *infoStr = @"Share link copied to clipboard";
			[self showItsAlert:infoStr andSyncFolderFlag:false];

		}else{
			_itsStreaming = false;
			[self showItsAlert:_wentWrongString andSyncFolderFlag:false];
		}
	});
}

-(void)handlePlayRequest
{
	[self setProgressIndicator];

	dispatch_async(dispatch_get_main_queue(), ^(void){
		vlc_player_Lock(_playerController.p_player);
		
		NSString *post = [NSString stringWithFormat:@"userGuid=%@&hash=%@", _itsUserUid, _itsStreamHash];
		NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
		NSString *apiUrl = [NSString stringWithFormat:@"%@%@", _itsApiUrl, @"stream/play"];
		NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:apiUrl]];
		[urlRequest setHTTPMethod:@"POST"];
		[urlRequest setHTTPBody:postData];
		//NSURLRequest * urlRequest = [NSURLRequest requestWithURL:aURL];
		NSURLResponse * response = nil;
		NSError * error = nil;
		NSData * data = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];

		[self removeProgressIndicator];

		if(!response){
			_itsStreaming = false;
			[self showItsAlert:_wentWrongString andSyncFolderFlag:false];
			vlc_player_Resume(_playerController.p_player);
			vlc_player_Unlock(_playerController.p_player);
			return;
		}

		NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
		NSString *status = [responseDictionary valueForKey:@"status"];
		NSInteger time = 0;
		if(status && [status isEqualToString:@"OK"]){
			time = [[responseDictionary objectForKey:@"time"] integerValue];
			vlc_player_SeekByTime(_playerController.p_player, (time * 1000000), VLC_PLAYER_SEEK_PRECISE,VLC_PLAYER_WHENCE_ABSOLUTE);
		}else{
			_itsStreaming = false;
			[self showItsAlert:_wentWrongString andSyncFolderFlag:false];
		}
		vlc_player_Resume(_playerController.p_player);
		vlc_player_Unlock(_playerController.p_player);
	});
}

-(void)handlePauseRequest
{
	[self setProgressIndicator];

	dispatch_async(dispatch_get_main_queue(), ^(void){
		NSString *post = [NSString stringWithFormat:@"userGuid=%@&hash=%@", _itsUserUid, _itsStreamHash];
		NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
		NSString *apiUrl =  [NSString stringWithFormat:@"%@%@", _itsApiUrl, @"session/pause"];
		NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:apiUrl]];
		[urlRequest setHTTPMethod:@"POST"];
		[urlRequest setHTTPBody:postData];
		NSURLResponse * response = nil;
		NSError * error = nil;
		NSData * data = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
		
		[self removeProgressIndicator];
		
		if(!response){
			_itsStreaming = false;
			[self showItsAlert:_wentWrongString andSyncFolderFlag:false];
			return;
		}
		
		NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
			NSString *status = [responseDictionary valueForKey:@"status"];
			if(status && [status isEqualToString:@"OK"])
			{
				NSLog(@"success in paused ;");
			}else{
				_itsStreaming = false;
				[self showItsAlert:_wentWrongString andSyncFolderFlag:false];
			}
	});
}

-(void)handleStopRequest:(bool)async withHash:(NSString*)hashToRemove
{
	NSString *post = [NSString stringWithFormat:@"userGuid=%@&hash=%@", _itsUserUid, hashToRemove];
	NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];

	NSString *apiUrl =  [NSString stringWithFormat:@"%@%@", _itsApiUrl, @"session/stop"];
	NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:apiUrl]];
	
	[urlRequest setHTTPMethod:@"POST"];
	[urlRequest setHTTPBody:postData];
	if(async){
		NSURLSessionDataTask *task =
		[[NSURLSession sharedSession] dataTaskWithRequest:urlRequest
										completionHandler:^(NSData *data,
										NSURLResponse *response,
										NSError *error) {
			//NSLog(@"async stop request completed %@", response);
			
		}];
		[task resume];
	}else{
		NSURLResponse * response = nil;
		NSError * error = nil;
		NSData * data = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
	}
}

-(void)handleConnectRequest:(VLCOpenInputMetadata*)inputData
{
	NSString *post = [NSString stringWithFormat:@"userGuid=%@&hash=%@", _itsUserUid, _itsStreamHash];
	NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	NSString *apiUrl =  [NSString stringWithFormat:@"%@%@", _itsApiUrl, @"session/get"];
	NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:apiUrl]];
	[urlRequest setHTTPMethod:@"POST"];
	[urlRequest setHTTPBody:postData];
	NSURLResponse * response = nil;
	NSError * error = nil;
	NSData * data = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
	
	if(!response){
		[self showItsAlert:_wentWrongString andSyncFolderFlag:false];
		return;
	}
		
	NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
	NSString *status = [responseDictionary valueForKey:@"status"];
	//NSString *status = @"OK";
	if(status && [status isEqualToString:@"OK"])
	{
		NSString *source = [responseDictionary valueForKey:@"source"];
		NSURL *respUri =  [NSURL URLWithString:[source stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]]];
		NSString *sch = respUri.scheme;
		
		if ([sch isEqualToString:@"file"]){
			NSString *file = [respUri lastPathComponent];
			bool success = [self checkLocalFile:file];
			if(!success) return;
			source = [NSString stringWithFormat:@"%@%@", _itsSyncFolder, file];
		}
		
		inputData.MRLString = source;
		inputData.itemName = @"custom name";
		_itsInitStream = true;
		[_playlistController addPlaylistItems:@[inputData]];
	}else{
		[self showItsAlert:_wentWrongString andSyncFolderFlag:false];
		return;
	}
}

-(bool)checkLocalFile:(NSString*)file
{
	_itsSyncFolder = [[NSUserDefaults standardUserDefaults]
	stringForKey:@"itsSyncFolder"];
	
	if(!_itsSyncFolder || [_itsSyncFolder length] == 0){ // check if sync folder exists
		NSString *infoStr = @"Sync directory not set";
		bool success = [self showItsAlert:infoStr andSyncFolderFlag:true];
		if(!success) return false;
	}

	NSString * strNoURLScheme = [[_itsSyncFolder stringByReplacingOccurrencesOfString:@"file://" withString:@""] stringByRemovingPercentEncoding];
	NSString *decodedFile = [file stringByRemovingPercentEncoding];
	NSString *entry;
	NSDirectoryEnumerator *enumerator;
	BOOL isDirectory;
	 
	NSFileManager *fileMgr = [NSFileManager defaultManager];
	[fileMgr changeCurrentDirectoryPath:strNoURLScheme];
	enumerator = [fileMgr enumeratorAtPath:strNoURLScheme];
	while ((entry = [enumerator nextObject]) != nil)
	{
	  // File or directory
		if ([fileMgr fileExistsAtPath:entry isDirectory:&isDirectory] && isDirectory){
			NSLog (@"Directory - %@", entry);
		}
		else{
			if([decodedFile isEqualToString:entry]) return true;
		}
	}
	
	NSString *infoStr = @"Shared file not found";
	[self showItsAlert:infoStr andSyncFolderFlag:false];
	return false;
}

@end
