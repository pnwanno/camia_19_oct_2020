import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../dbs.dart';
import '../globals.dart' as globals;

class DictHome extends StatefulWidget{
  _DictHome createState(){
    return _DictHome();
  }
}

class _DictHome extends State<DictHome>{
  @override
  initState(){
    super.initState();
  }

  DBTables _dbTables= DBTables();
  fetchWordofDay()async{

  }//word of day

  double _globpostop=0;
  BuildContext _homeContext;
  Size _homeSize;
@override
  Widget build(BuildContext context) {
  _homeContext=context;
  _homeSize= MediaQuery.of(_homeContext).size;
    return MaterialApp(
      home: FocusScope(
        autofocus: true,
        child: Container(
          child: Stack(
            children: <Widget>[
              Container(
                child: ListView(
                  children: <Widget>[
                    Container(

                    )
                  ],
                ),
              ),
              Positioned(
                left: 0, top: _globpostop,
                width: _homeSize.width,
                child: Container(
                  child: Column(
                    children: <Widget>[

                    ],
                  ),
                ),
              )
            ],
          ),
        ),
        onFocusChange: (bool _isFocused){

        },
      ),
    );
  }//route's build method

  ScrollController _homeLiCtr= ScrollController();
  @override
  void dispose() {
    super.dispose();
    _homeLiCtr.dispose();
  }
}