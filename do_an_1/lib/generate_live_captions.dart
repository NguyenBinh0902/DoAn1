import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/placeholder.dart';
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

class GenerateLiveCaptions extends StatefulWidget {
  const GenerateLiveCaptions({super.key});

  @override
  State<GenerateLiveCaptions> createState() => _GenerateLiveCaptionsState();
}

class _GenerateLiveCaptionsState extends State<GenerateLiveCaptions> {
  late List<CameraDescription> cameras;
  var controller;
  var resultText = "";
  Future<void> detectCameras() async {
    cameras = await availableCameras();
  }

  void initializeController() {
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      const interval = const Duration(seconds: 5);
      new Timer.periodic(interval, (Timer t) => capturePictures());
    });
  }

  buildCameraPreview() {
    var size = MediaQuery.of(context).size.width;
    return Container(
      child: Column(
        children: <Widget>[
          Container(
            height: size,
            width: size,
            child: CameraPreview(controller),
          ),
          Text(resultText)
        ],
      ),
    );
  }

  capturePictures() async {
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/generate_caption_images';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp}.jpg';
    controller.takePicture(filePath).then((_) {
      File imgFile = File(filePath);
      fetchResponse(imgFile);
    });
  }

  Future<Map<String, dynamic>?> fetchResponse(File image) async {
    final mimeTypeData =
        lookupMimeType(image.path, headerBytes: [0xff, 0xD8])?.split('/');
    final imageUploadRequest = http.MultipartRequest(
        'POST', Uri.parse("http://localhost:5000/model/predict"));
    final file = await http.MultipartFile.fromPath('image', image.path,
        contentType: MediaType(mimeTypeData![0], mimeTypeData[1]));
    imageUploadRequest.fields['ext'] = mimeTypeData[1];
    imageUploadRequest.files.add(file);
    try {
      final streamedRespone = await imageUploadRequest.send();
      final response = await http.Response.fromStream(streamedRespone);
      final Map<String, dynamic> responseData = json.decode(response.body);
      parseResponse(responseData);
      return responseData;
    } catch (e) {
      print(e);
      return null;
    }
  }

  void parseResponse(var response) {
    String resString = "";
    var predictions = response['predictions'];
    for (var prediction in predictions) {
      var caption = prediction['caption'];
      var probability = prediction['probability'];
      resString = resString + '${caption}: ${probability}\n\n';
    }
    setState(() {
      resultText = resString;
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void initState() {
    super.initState();
    detectCameras().then((_) {
      initializeController();
    });
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Image Caption'),
      ),
      body: (controller.value.isInitialized)
          ? buildCameraPreview()
          : new Container(),
    );
  }
}
