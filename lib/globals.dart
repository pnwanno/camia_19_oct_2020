library camia.globals;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

String email="";
String password="";
String fullname="";
String phone="";
String dp="";
String userId="";

String globBaseUrl="https://camia.blwcampusministry.com/app-engine/front-api.php";

class KjToast extends StatelessWidget{
  KjToast(this._globalFontSize, this._screenSize, this._toastCtrl);
  final Size _screenSize;
  final double _globalFontSize;
  final StreamController _toastCtrl;
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0, bottom: _screenSize.height * .4,
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