import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/services.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<AssetEntity> videos = [];
  String? currentFilter = 'Recent';
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _isError = false;

  final List<String> filters = ['Recent', 'Largest', 'Longest'];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final PermissionState state = await PhotoManager.requestPermissionExtend();
    if (state.isAuth) {
      _loadVideos();
    } else {
      PhotoManager.openSetting();
    }
  }

  Future<void> _loadVideos() async {
    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
      );
      final List<AssetEntity> allVideos = await albums[0].getAssetListRange(
        start: 0,
        end: 1000,
      );
      setState(() {
        videos = allVideos;
        _isLoading = false;
      });
      _applyFilter(currentFilter!);
    } catch (e) {
      setState(() {
        _isError = true;
        _isLoading = false;
      });
    }
  }

  void _applyFilter(String filter) {
    setState(() {
      currentFilter = filter;
      switch (filter) {
        case 'Recent':
          videos.sort((a, b) => b.modifiedDateTime.compareTo(a.modifiedDateTime));
          break;
        case 'Largest':
          videos.sort((a, b) {
            final sizeA = (a.size ?? 0.0) as double;  // Cast to double
            final sizeB = (b.size ?? 0.0) as double;  // Cast to double
            return sizeB.compareTo(sizeA); // Compare in descending order
          });
          break;
        case 'Longest':
          videos.sort((a, b) => (b.duration ?? 0).compareTo(a.duration ?? 0));
          break;
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Gallery'),
        actions: [
          DropdownButton<String>(
            value: currentFilter,
            items: filters.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: (value) => _applyFilter(value!),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isError
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 50),
            const SizedBox(height: 10),
            const Text(
              'Error loading videos. Please try again later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      )
          : GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.7,
        ),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          return VideoThumbnail(
            video: videos[index],
            onTap: () => _playVideo(videos[index]),
          );
        },
      ),
    );
  }

  Future<void> _playVideo(AssetEntity video) async {
    final file = await video.file;
    if (file != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoPath: file.path,
            orientation: video.orientation,
          ),
        ),
      );
    }
  }
}

class VideoThumbnail extends StatelessWidget {
  final AssetEntity video;
  final VoidCallback onTap;

  const VideoThumbnail({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: FutureBuilder<Uint8List?>(
        future: video.thumbnailData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasData) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(snapshot.data!, fit: BoxFit.cover), // Show the original thumbnail
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Text(
                    '${((video.size ?? 0) as int) ~/ 1024} KB',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 2,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return const Center(child: Icon(Icons.error, color: Colors.red)); // In case of error
        },
      )

    );
  }
}


class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final int orientation;

  const VideoPlayerScreen({required this.videoPath, required this.orientation});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  bool _isPlaying = true;
  BoxFit _videoFit = BoxFit.contain;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _toggleOrientation() {
    if (MediaQuery.of(context).orientation == Orientation.portrait) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  void _changeVideoFit(BoxFit fit) {
    setState(() => _videoFit = fit);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
            if (_showControls)
              Container(
                color: Colors.black54,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppBar(
                      backgroundColor: Colors.transparent,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.screen_rotation),
                          onPressed: _toggleOrientation,
                        ),
                        PopupMenuButton<BoxFit>(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: BoxFit.contain,
                              child: Text('Fit'),
                            ),
                            const PopupMenuItem(
                              value: BoxFit.cover,
                              child: Text('Fill'),
                            ),
                            const PopupMenuItem(
                              value: BoxFit.fill,
                              child: Text('Stretch'),
                            ),
                          ],
                          onSelected: _changeVideoFit,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_10),
                          onPressed: () => _controller.seekTo(
                              _controller.value.position - const Duration(seconds: 10)),
                        ),
                        IconButton(
                          icon: Icon(
                            _controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            size: 40,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_controller.value.isPlaying) {
                                _controller.pause();
                              } else {
                                _controller.play();
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.forward_10),
                          onPressed: () => _controller.seekTo(
                              _controller.value.position + const Duration(seconds: 10)),
                        ),
                      ],
                    ),
                    VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.red,
                        bufferedColor: Colors.grey,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
