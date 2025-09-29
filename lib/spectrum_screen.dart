import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:fl_chart/fl_chart.dart'; //fl_chart is the package for making a chart.
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class SpectrumScreen extends StatefulWidget {
  final CameraDescription camera;
  const SpectrumScreen({super.key, required this.camera});

  @override
  State<SpectrumScreen> createState() => _SpectrumScreenState();

  
}

class _SpectrumScreenState extends State<SpectrumScreen> {
  late CameraController _controller;
  Future<void>? _initializeControllerFuture;
  List<double> intensities = [];

  List<double>? calibrationSpectrum;
  String selectedReference = "Mercury"; // default
  final List<String> references = ["Mercury", "Fluorescent", "LED"]; //choose spectra

//  void _saveCalibrationSpectrum() {
//     setState(() {
//       calibrationSpectrum = List.from(intensities); // clone current intensities
//     });
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text("Calibration spectrum saved!")),
//     );
//   }

  @override
  void initState() {
    super.initState();
    _initPermissions();
  }

  Future<void> _initPermissions() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      await _initCamera();
    } else {
      print("Camera permission denied");
    }
  }

  Future<void> _initCamera() async {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.low,
      enableAudio: false,
    );


    _initializeControllerFuture = _controller.initialize().then((_) {
      _controller.startImageStream(
        _processCameraImage,
      ); //streams frames and passages it to _processCameraImage, called for everyframe
    });
  }

  void _processCameraImage(CameraImage image) {
    //frame comes in as Camera image. Android uses YUV420 format. Y is luma = brightness, UxV is a 2-axis plane with colors.
    // https://en.wikipedia.org/wiki/Chroma_subsampling; explains the 420 part. Y is more detailed/higher resolution than UV (colors)
    // Extract grayscale intensities from center vertical strip
    final centerY = image.width ~/ 2; //finds center of vertical strip.
    List<double> newIntensities = [];

    for (int x = 0; x < image.height; x++) {
      // YUV420: image.planes[0] is luminance (Y), planes[1],[2] are color channels U and V.
      int sum = 0;
      for (int dy = -12; dy <= 12; dy++) {//loop so 25 pixels in center are averaged
        
        
        final int pixelIndex = (centerY + dy) * image.planes[0].bytesPerRow + x; // finding the index for the pixel. y is what row, so mult that by number of bytes per row. centerx with distance to center
          
        sum += image.planes[0].bytes[pixelIndex]; //get luma(brightness) of indexed pixel
          
        
      }
        
      final double avgIntensity = sum / (25);
      newIntensities.add(avgIntensity); //stores all pixel brightness
    }

    setState(() {
      intensities = newIntensities; //purpose is to update UI with intensities.
    });
  }

  @override
  void dispose() {
    //when screen is closed, stops and frees the camera
    _controller.dispose();
    super.dispose();
  }

  List<FlSpot> _buildPlotData() {
    //defining the function which returns the list containing the FlSpot object. FlSpot contains intensities x,y
    return intensities.asMap().entries.map(
      //intensities is defined above, with the data from the camera. .asMap().entries turns a list of doubles into (index: values)
      (entry) {
        //map(entry){...} turns each (index: value) into object-- the FlSpot
        int y = entry
            .key; //even though this is labeled y, it sets up what will be our x axis in the graph, row index number. will need to correlate to wavelength
        double intensity = entry.value; //intensity value
        return FlSpot(
          y.toDouble(),
          intensity,
        ); //makes to FlSpot. This is a type of object with data to be graphed
        //FlSpot read up: https://github.com/imaNNeo/fl_chart/blob/main/repo_files/documentations/base_chart.md#FlSpot
      },
    ).toList(); //turns everything back into a list.
  }

  Future<File> _saveCsvFile() async {
  final directory = await getApplicationDocumentsDirectory();
  final path = '${directory.path}/spectrum_data.csv';

  // convert intensities list into CSV rows: index,intensity
  final csvData = intensities.asMap().entries.map((entry) {
    final index = entry.key;
    final value = entry.value;
    return '$index,$value';
  }).join('\n');

  final file = File(path);
  return file.writeAsString(csvData);
  }

Future<void> _shareCsv() async {
try {
    final file = await _saveCsvFile();
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Here is my spectrum data!',
    );

    await _initCamera();
  } catch (e) {
    print("Error sharing CSV: $e");
  }
}







  @override
  Widget build(BuildContext context) {
    //builds the UI
    return Scaffold(
      appBar: AppBar(title: const Text("Spectrophotometer")),
                  
      body: _initializeControllerFuture == null
    ? const Center(child: Text("Waiting for camera permission..."))
       : FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            //waits until camera is ready
            return Column(
              children: [
                // Camera preview on top
                Expanded(flex: 2, child: CameraPreview(_controller)),
                Row(
                  children: [
                    // FloatingActionButton.small(
                    //   heroTag: "calibrate",
                    //   onPressed: _saveCalibrationSpectrum,  
                    //   child: Icon(Icons.auto_graph),
                    // ),
                    SizedBox(height: 10),
                    FloatingActionButton.large(
                      heroTag: "share",
                      onPressed: _shareCsv,
                      child: Icon(Icons.share),
                    ),
                  ],

                ),




                // Padding(
                //   padding: const EdgeInsets.all(8.0),
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.center,
                //     children: [
                //       const Text("Reference: "),
                //       DropdownButton<String>(
                //         value: selectedReference,
                //         items: references.map((ref) {
                //           return DropdownMenuItem<String>(
                //             value: ref,
                //             child: Text(ref),
                //           );
                //         }).toList(),
                //         onChanged: (newValue) {
                //           setState(() {
                //             selectedReference = newValue!;
                //           });
                //         },
                //       ),
                //     ],
                //   ),
                // ),



                // Spectrum plot on bottom
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: LineChart(
                      LineChartData(
                        // Enable grid lines & borders
                        gridData: FlGridData(show: true),
                        borderData: FlBorderData(show: true),

                        // === AXES & LABELS ===
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            // Y axis
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40, // space for numbers
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value
                                      .toInt()
                                      .toString(), // show integer values
                                  style: TextStyle(fontSize: 12),
                                );
                              },
                            ),
                            axisNameWidget: Text(
                              "Intensity",
                            ), // Label for Y axis
                            axisNameSize: 20,
                          ),
                          bottomTitles: AxisTitles(
                            // X axis
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 50, // show every 50 pixels for clarity
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(), // pixel row index
                                  style: TextStyle(fontSize: 12),
                                );
                              },
                            ),
                            axisNameWidget: Text(
                              "Pixel Position (Top → Bottom)",
                            ), // Label for X axis
                            axisNameSize: 20,
                          ),
                          rightTitles: AxisTitles(
                            // Hide right side labels
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            // Hide top labels
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),

                        // === THE LINE PLOT ===
                        lineBarsData: [
                          LineChartBarData(
                            spots: _buildPlotData(),
                            isCurved: false,
                            barWidth: 2,
                            color: Colors.blue,
                            dotData: FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),


              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),


  //floatingActionButton: FloatingActionButton(
   // onPressed: () async {
    //  await _shareCsv();
    //},
    //child: const Icon(Icons.share),
  //),



    );
  }
}
