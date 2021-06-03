import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('设置'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 15,vertical: 6),
            child: Text('外观'),
            color: Colors.grey.withOpacity(0.2),
          ),
        ListTile(
          title: Text('深色主题'),
          trailing: Switch(onChanged: null, value: false,),
        )
      ],),
    );
  }
}
