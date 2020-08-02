library camia.globals;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart' as urlLauncher;

String email="";
String password="";
String fullname="";
String phone="";
String dp="";
String userId="";
Color wallContainerShadow= Color.fromRGBO(32, 32, 32, 1);

String globBaseUrl="https://camia.blwcampusministry.com/app-engine/front-api.php";
String globBaseUrl2="https://camia.blwcampusministry.com/app-engine/front-api2.php";

StreamController globalCtr= StreamController.broadcast();


enum KWordcase{
  sentence_case,
  proper_case,
  camel_case
}
///Custom method to less familiar word cases
String kChangeCase(String word, KWordcase to){
  String _tolower= word.toLowerCase().replaceAll("jesus", "Jesus").replaceAll("christ", "Christ").replaceAll("god", "God");
  List<String> _brkword= _tolower.split(" ");
  int _count= _brkword.length;
  if(to == KWordcase.sentence_case){
    String _firstchar= _tolower.substring(0,1);
    return _firstchar.toUpperCase() + _tolower.replaceFirst(_firstchar.toLowerCase(), "");
  }
  String _retword="";
  for(int _k=0; _k<_count; _k++){
    if(to ==  KWordcase.proper_case){
      _retword += " " + kChangeCase(_brkword[_k], KWordcase.sentence_case);
    }
    else if(to ==  KWordcase.camel_case){
      if(_k == 0){
        _retword=_brkword[0];
      }
      else{
        _retword += " " + kChangeCase(_brkword[_k], KWordcase.sentence_case);
      }
    }
  }
  return _retword.trim();
}

Path logoPath(Size size){
  Path path=Path();
  path.lineTo(size.width * 0.27, size.height);
  path.cubicTo(size.width * 0.23, size.height * 0.98, size.width * 0.17, size.height * 0.92, size.width * 0.15, size.height * 0.88);
  path.cubicTo(size.width * 0.13, size.height * 0.82, size.width * 0.12, size.height * 0.75, size.width * 0.14, size.height * 0.66);
  path.cubicTo(size.width * 0.16, size.height * 0.53, size.width * 0.16, size.height * 0.49, size.width * 0.09, size.height * 0.38);
  path.cubicTo(size.width * 0.02, size.height * 0.26, size.width * 0.01, size.height * 0.24, size.width * 0.02, size.height * 0.18);
  path.cubicTo(size.width * 0.02, size.height * 0.11, size.width * 0.05, size.height * 0.07, size.width * 0.11, size.height * 0.03);
  path.cubicTo(size.width * 0.18, -0.02, size.width * 0.27, -0.01, size.width * 0.41, size.height * 0.08);
  path.cubicTo(size.width * 0.52, size.height * 0.14, size.width * 0.63, size.height * 0.18, size.width * 0.73, size.height * 0.19);
  path.cubicTo(size.width * 0.85, size.height / 5, size.width * 0.88, size.height * 0.22, size.width * 0.93, size.height * 0.26);
  path.cubicTo(size.width * 0.98, size.height * 0.3, size.width * 1.02, size.height * 0.37, size.width * 1.02, size.height * 0.46);
  path.cubicTo(size.width * 1.02, size.height * 0.61, size.width * 0.92, size.height * 0.72, size.width * 0.75, size.height * 0.76);
  path.cubicTo(size.width * 0.65, size.height * 0.79, size.width * 0.61, size.height * 0.81, size.width * 0.55, size.height * 0.89);
  path.cubicTo(size.width * 0.47, size.height * 0.97, size.width * 0.42, size.height, size.width * 0.35, size.height);
  path.cubicTo(size.width * 0.32, size.height, size.width * 0.28, size.height, size.width * 0.27, size.height);
  path.cubicTo(size.width * 0.27, size.height, size.width * 0.27, size.height, size.width * 0.27, size.height);
  path.close();
  return path;
}

class KjToast extends StatelessWidget{
  KjToast(this._globalFontSize, this._screenSize, this._toastCtrl, this._bottomPosition);
  final Size _screenSize;
  final double _globalFontSize;
  final StreamController _toastCtrl;
  final double _bottomPosition;
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0, bottom: _bottomPosition,
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          width: _screenSize.width,
          alignment: Alignment.center,
          child: StreamBuilder(
              stream: _toastCtrl.stream,
              builder: (BuildContext ctx,AsyncSnapshot snapshot){
                if(snapshot.hasData && snapshot.data["visible"]){
                  return TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                          begin: _screenSize.width * .5,
                          end: _screenSize.width - 32
                      ),
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      onEnd: (){
                        Future.delayed(
                            snapshot.data["duration"],
                                (){
                              _toastCtrl.add({
                                "visible": false,
                                "text": "",
                                "duration": Duration(milliseconds: 1)
                              });
                            }
                        );
                      },
                      builder: (BuildContext ctx, double dval, Widget w){
                        return AnimatedContainer(
                            alignment: Alignment.center,
                            padding: EdgeInsets.only(left:16, right:16, top:9, bottom: 9),
                            margin: EdgeInsets.only(left:16, right: 16),
                            decoration: BoxDecoration(
                                color: Color.fromRGBO(5, 5, 5, 1),
                                borderRadius: BorderRadius.circular(16)
                            ),
                            duration: Duration(milliseconds: 100),
                            width: dval,
                            child: AnimatedOpacity(
                              opacity: dval< (_screenSize.width - 32) ? 0 : 1,
                              duration: Duration(milliseconds: 500),
                              child: Text(
                                dval< (_screenSize.width - 32) ? "" : snapshot.data["text"],
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _globalFontSize + 1
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            )
                        );
                      }
                  );
                }
                else{
                  return Container();
                }
              }
          ),
        ),
      ),
    );
  }

  ///Mimics the native android toast
  showToast({String text, Duration duration}){
    _toastCtrl.add({
      "visible": true,
      "text": text,
      "duration": duration
    });
  }//show toast
}




RegExp _htag= RegExp(r"^#[a-z0-9_]+$", caseSensitive: false);
RegExp _href= RegExp(r"[a-z0-9-]+\.[a-z0-9-]+", caseSensitive: false);
RegExp _atTag= RegExp(r"^@[a-z0-9_]+$", caseSensitive: false);
RegExp _isEmail= RegExp(r"^[a-z_0-9.-]+\@[a-z0-9-]+\.[a-z0-9-]+(\.[a-z0-9-]+)*$", caseSensitive: false);
RegExp _phoneExp= RegExp(r"^[0-9 -]+$");

///Tries to open a URL or a local link (an app link)
followLink(String _link){
  if(_isEmail.hasMatch(_link)){
    urlLauncher.canLaunch("mailto:$_link").then((_canLaunch) {
      if(_canLaunch){
        urlLauncher.launch("mailto:$_link");
      }
    });
  }
  else if(_href.hasMatch(_link)){
    String _newhref= "https://" + _link.replaceAll(RegExp(r"^https?:\/\/",caseSensitive: false), "");
    urlLauncher.canLaunch(_newhref).then((_canLaunch) {
      if(_canLaunch){
        urlLauncher.launch(_newhref);
      }
    });
  }
  else if(_phoneExp.hasMatch(_link)){
    String _newphone= "tel:$_link";
    urlLauncher.canLaunch(_newphone).then((_canLaunch) {
      if(_canLaunch){
        urlLauncher.launch(_newphone);
      }
    });
  }
}

parseTextForLinks(String _textData){
  _textData=_textData.replaceAll("\n", "__kjut__ ");
  List<String> _brkPostText= _textData.split(" ");
  int _brkPostTextCount= _brkPostText.length;
  List<InlineSpan> _postTextSpan= List<InlineSpan>();
  String _curPostText="";
  for(int _j=0; _j<_brkPostTextCount; _j++){
    String _curText=_brkPostText[_j];
    if(_phoneExp.hasMatch(_curText) || _isEmail.hasMatch(_curText) || _htag.hasMatch(_curText) || _atTag.hasMatch(_curText) || _href.hasMatch(_curText)){
      _postTextSpan.add(
          TextSpan(
              text: _curPostText.replaceAll("__kjut__ ", "\n") + " ",
              style: TextStyle(
                  height: 1.5
              )
          )
      );
      _curPostText="";
      _postTextSpan.add(
          TextSpan(
              text: _curText.replaceAll("__kjut__ ", "\n") + " ",
              style: TextStyle(
                  color: (_isEmail.hasMatch(_curText)) ? Colors.orange :
                  (_href.hasMatch(_curText) || _phoneExp.hasMatch(_curText)) ? Colors.blue : Colors.blueGrey,
                  height: 1.5
              ),
              recognizer: TapGestureRecognizer()..onTap=(){
                followLink(_curText);
              }
          )
      );
    }
    else{
      _curPostText += _curText.replaceAll("__kjut__ ", "\n") + " ";
    }
  }
  _postTextSpan.add(
      TextSpan(
          text: _curPostText.replaceAll("__kjut__ ", "\n"),
          style: TextStyle(
              height: 1.5
          )
      )
  );
  return _postTextSpan;
}//parse text for links

convertToK(int val){
  List<String> units=["K", "M", "B"];
  double remain = val/1000;
  int counter=-1;
  if(remain>1) counter++;
  while(remain>999){
    counter++;
    remain /=1000;
  }
  if(counter>-1) return remain.toStringAsFixed(1) + units[counter];
  return "$val";
}//convert to k m or b


class KjutPullRefresh extends StatefulWidget{
  _KjutPullRefresh createState(){
    return _KjutPullRefresh();
  }
  final double pullRefreshLoadHeight;
  final ScrollController listViewCtr;
  final cb;
  final Widget child;
  KjutPullRefresh({
    this.pullRefreshLoadHeight,
    this.listViewCtr,
    this.cb,
    this.child
  });
}

class _KjutPullRefresh extends State<KjutPullRefresh>{
  @override
  Widget build(BuildContext context) {
    return kjPullToRefresh(child: widget.child);
  }

  StreamController _pullRefreshCtr= StreamController.broadcast();
  double _pullRefreshHeight=0;
  ///Pass a listview as child widget to this widget
  Widget kjPullToRefresh({Widget child}){
    return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerUp: (PointerUpEvent pue){
          if(_pullRefreshHeight< widget.pullRefreshLoadHeight){
            _pullRefreshHeight =0;
            _pullRefreshCtr.add("kjut");
          }
          else{
            Future.delayed(
                Duration(milliseconds: 1500),
                    (){
                  //call the refresh function
                  _pullRefreshHeight=0;
                  _pullRefreshCtr.add("kjut");
                  widget.cb();
                }
            );
          }
        },
        onPointerMove: (PointerMoveEvent pme){
          Offset _delta= pme.delta;
          if(widget.listViewCtr.position.atEdge && !_delta.direction.isNegative){
            double dist= math.sqrt(_delta.distanceSquared);
            if(_pullRefreshHeight < widget.pullRefreshLoadHeight){
              _pullRefreshHeight +=(dist/3);
              _pullRefreshCtr.add("kjut");
            }
          }
        },
        child: child
    );
  }//kjut pull to refresh

  @override
  void dispose() {
    super.dispose();
    _pullRefreshCtr.close();
  }
}