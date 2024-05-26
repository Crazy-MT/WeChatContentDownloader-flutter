import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'package:path_provider/path_provider.dart';
import 'package:html2md/html2md.dart' as html2md;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '微信公众号下载器',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _urlController = TextEditingController();
  final List<String?> _imageUrls = [];
  final List<String?> _videoUrls = [];
  Map<String, String> headers = {
    'Accept': '*/*',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6',
    'Connection': 'keep-alive',
    'Origin': 'https://mp.weixin.qq.com',
    'Referer': 'https://mp.weixin.qq.com/',
    'Sec-Fetch-Dest': 'video',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Site': 'cross-site',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36 Edg/119.0.0.0',
    'sec-ch-ua':
        '"Microsoft Edge";v="119", "Chromium";v="119", "Not?A_Brand";v="24"',
    'sec-ch-ua-mobile': '?1',
    'sec-ch-ua-platform': '"Android"'
  };
  String? _outPutPath;
  String? _outPutFolder;

  String _progressText = '';

  @override
  void initState() {
    super.initState();
    // _urlController.text = "https://mp.weixin.qq.com/s/P3ZKQhUr8bWlAv27SXI2Ww";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('微信公众号下载器'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () async {
                String? selectedDirectory =
                    await FilePicker.platform.getDirectoryPath();

                if (selectedDirectory != null) {
                  setState(() {
                    _outPutPath = selectedDirectory;
                  });
                }
              },
              child: Text(_outPutPath ?? '选择保存目录'),
            ),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(labelText: '输入公众号地址'),
            ),
            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: _fetchContent,
              child: const Text('下载'),
            ),
            const SizedBox(height: 20.0),
            const Text('图片:'),
            Expanded(
              child: ListView.builder(
                itemCount: _imageUrls.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: SelectableText(_imageUrls[index] ?? ""),
                  );
                },
              ),
            ),
            const Text('视频:'),
            Expanded(
              child: ListView.builder(
                itemCount: _videoUrls.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: SelectableText(_videoUrls[index] ?? ""),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // 在macOS上执行打开Finder的Shell命令
                // 使用open命令打开指定目录
                Process.run('open', [_outPutFolder ?? ""])
                    .then((ProcessResult results) {
                  if (results.exitCode == 0) {
                    print('目录 $_outPutFolder 已成功打开');
                  } else {
                    print('无法打开目录 $_outPutFolder ：${results.stderr}');
                  }
                });
              },
              child: Text(
                _progressText,
                style: const TextStyle(fontSize: 20, color: Colors.red),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _fetchContent() async {
    String url = _urlController.text;
    if (url.isEmpty) {
      setState(() {
        _progressText = '请输入微信公众号地址';
      });
      return;
    }

    setState(() {
      _imageUrls.clear();
      _videoUrls.clear();
      _progressText = '下载中……';
    });
    try {
      Dio dio = Dio();

      dio.options.headers = headers;
      // dio.interceptors.add(LogInterceptor(responseBody: true));
      dio.options.responseType = ResponseType.plain;
      Response response = await dio.get(_urlController.text);

      response = await dio.get(url);
      if (response.statusCode == 200) {
        dom.Document document = parser.parse(response.data);

        // 提取 Meta 标签内容
        dom.Element? metaTag =
            document.querySelector('meta[property="og:title"]');
        String title = metaTag != null
            ? metaTag.attributes['content'] ?? "内容未找到"
            : "内容未找到";

        // 提取特定类的 div 内容
        dom.Element? divContent = document.querySelector('div.rich_media_wrp');
        String content =
            divContent != null ? divContent.innerHtml : "指定的 div 未找到";

        // print('MTMTMT  $title $content');

        // 获取本地存储路径
        Directory? appDocDir = await getApplicationDocumentsDirectory();
        String? appDocPath = _outPutPath ?? (appDocDir.path);

        // 将文件写入本地
        Directory directory = Directory('$appDocPath/$title'); // 这里指定路径;
        bool exists = await directory.exists();
        if (!exists) {
          directory.create();
        }
        File file = File("${directory.path}/$title.html");
        await file.writeAsString(content);
        File mdFile = File("${directory.path}/$title.md");
        await mdFile.writeAsString(html2md.convert(content));

        // 提取图片和视频链接
        List<dom.Element> imageElements = document.getElementsByTagName('img');
        var imageUrls = [];
        imageElements.asMap().forEach((index, img) {
          var dataSrc = img.attributes['data-src'];
          if (dataSrc != null) {
            imageUrls.add(dataSrc);
          }
        });
        imageUrls.asMap().forEach((index, element) async {
          Uri uri = Uri.parse(element ?? "");
          Map<String, String> queryParams = uri.queryParameters;

          // 获取wx_fmt参数的值
          String? wxFmtValue = queryParams['wx_fmt'];
          await downloadFile(
              element ?? "", title, "图片", "$index.${wxFmtValue ?? ""}");
        });

        String videoInfo = extractVideoInfos(response.data);
        String videoInfoJson = convertJsToDart(videoInfo);
        List<Map<String, dynamic>> dataList =
            jsonDecode(videoInfoJson).cast<Map<String, dynamic>>();
        for (Map video in dataList) {
          for (Map v in video['mp_video_trans_info']) {
            await downloadFile(v['url'] ?? "", title, "视频",
                "${v['video_quality_wording']}${v['filesize']}.mp4");
          }
        }

        setState(() {
          _progressText =
              '成功: 图片数量 ${_imageUrls.length}，视频数量 ${_videoUrls.length} 点击快速打开下载目录';
        });
      } else {
        print('Failed to fetch content: ${response.statusCode}');
        setState(() {
          _progressText = '失败  点击快速打开下载目录';
        });
      }
    } catch (e) {
      setState(() {
        _progressText = '失败 $e  点击快速打开下载目录';
      });
    }
  }

  Future<void> downloadFile(
      String fileUrl, String title, String folder, String imgName) async {
    Dio dio = Dio();
    try {
      dio.options.headers = headers;
      dio.options.responseType = ResponseType.bytes;
      Response response = await dio.get(fileUrl);

      Directory? appDocDir = await getApplicationDocumentsDirectory();
      _outPutPath = _outPutPath ?? (appDocDir.path);
      String? appDocPath = _outPutPath;

      Directory directory = Directory('$appDocPath/$title/$folder'); // 这里指定路径;
      bool exists = await directory.exists();
      if (!exists) {
        directory.create();
      }
      _outPutFolder = directory.path;
      File file = File("${directory.path}/$imgName");
      await file.writeAsBytes(response.data);

      print('文件已下载到：${file.path}');
      setState(() {
        if ("图片" == folder) {
          _imageUrls.add("成功：$fileUrl");
        }

        if ("视频" == folder) {
          _videoUrls.add("成功：$fileUrl");
        }
      });
    } catch (e) {
      print('下载文件时出现错误：$e');
      setState(() {
        if ("图片" == folder) {
          _imageUrls.add("失败：$e $fileUrl");
        }

        if ("视频" == folder) {
          _videoUrls.add("失败：$e $fileUrl");
        }
      });
    }
  }

  String extractVideoInfos(String htmlContent) {
    String startPhrase = "var videoPageInfos =";
    String endPhrase = ";\nwindow.__videoPageInfos";

    int startIndex = htmlContent.indexOf(startPhrase);
    int endIndex = htmlContent.indexOf(endPhrase);

    String videoInfos;
    if (startIndex != -1 && endIndex != -1) {
      videoInfos = htmlContent
          .substring(startIndex + startPhrase.length, endIndex)
          .trim();
    } else {
      videoInfos = "指定内容未找到";
    }
    return videoInfos;
  }

  String convertJsToDart(String dataStr) {
    // 移除 JavaScript 的 '||' 和 '* 1' 表达式
    dataStr = dataStr.replaceAll("|| ''", '');
    dataStr = dataStr.replaceAll("|| 0", '');
    dataStr = dataStr.replaceAllMapped(
        RegExp(r"'(\d+)' \* 1"), (match) => match.group(1)!);
    dataStr =
        dataStr.replaceAll(").replace(/^http(s?):/, location.protocol)", '');
    dataStr = dataStr.replaceAll("'", '"');
    dataStr = dataStr.replaceAllMapped(
        RegExp(r'(\w+):'), (match) => '"${match.group(1)}":');
    dataStr = dataStr.replaceAll('\\x26amp;', '&');
    dataStr = dataStr.replaceAll(RegExp(r'\s+'), '');
    dataStr = dataStr.replaceAll(RegExp(r',\]'), ']');
    dataStr = dataStr.replaceAll(RegExp(r',\}'), '}');

    dataStr = dataStr.replaceAll('(""https"', '"https');
    dataStr = dataStr.replaceAll('(""http"', '"https');

    dataStr = dataStr.replaceAll('""https"', '"https');
    dataStr = dataStr.replaceAll('""http"', '"https');

    return dataStr;
  }
}
