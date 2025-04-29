import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({Key? key}) : super(key: key);

  @override
  _PersonalInfoPageState createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  String name = '王小明';
  String gender = '男';
  String birthday = '1996-01-01'; // ← 改成生日
  String bloodType = 'O';
  String heightValue = '175';
  String weightValue = '68';
  String? avatarUrl;
  File? _avatarImage;
  String? uid;

  final String avatarFileName = 'avatar.png';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    uid = prefs.getString('uid');
    if (uid != null && uid!.isNotEmpty) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('user_profile')
          .doc(uid)
          .get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          name = data['name'] ?? name;
          gender = data['gender'] ?? gender;
          birthday = data['dob'] ?? birthday; // ← 讀生日欄位
          bloodType = data['blood_type'] ?? bloodType;
          heightValue = data['height'] ?? heightValue;
          weightValue = data['weight'] ?? weightValue;
          avatarUrl = data['avatar_url'];
        });
      }
    }
  }

  int calculateAge(String birthday) {
    try {
      DateTime birthDate = DateTime.parse(birthday);
      DateTime today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return 0; // 如果格式錯誤，回傳0歲
    }
  }

  Future<void> _changePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File tempFile = File(pickedFile.path);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("預覽照片"),
          content: Image.file(tempFile, width: 200, height: 200),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final directory = await getApplicationDocumentsDirectory();
                  final path = directory.path;
                  final savedFile = await tempFile.copy('$path/$avatarFileName');

                  setState(() {
                    _avatarImage = savedFile;
                  });

                  if (uid != null) {
                    final storageRef = FirebaseStorage.instance
                        .ref()
                        .child('user_avatars/$uid/$avatarFileName');
                    await storageRef.putFile(_avatarImage!);

                    String downloadURL = await storageRef.getDownloadURL();
                    setState(() {
                      avatarUrl = downloadURL;
                    });

                    await FirebaseFirestore.instance
                        .collection('user_profile')
                        .doc(uid)
                        .update({'avatar_url': avatarUrl});
                  }
                } catch (e) {
                  print('儲存頭像失敗: $e');
                }
                Navigator.pop(context);
              },
              child: const Text("確定"),
            ),
          ],
        ),
      );
    }
  }

  void editInfo(String field, String currentValue, Function(String) onSave) {
    TextEditingController controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('編輯 $field'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: '輸入新的 $field (生日格式: yyyy-MM-dd)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  void editNumericInfo(String field, String currentValue, Function(String) onSave) {
    TextEditingController controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('編輯 $field'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: '只輸入數字 (不含單位)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(context);
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }

  void editBloodType(String currentValue, Function(String) onSave) {
    String selectedBloodType = currentValue;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('編輯血型'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DropdownButton<String>(
                value: selectedBloodType,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      selectedBloodType = newValue;
                    });
                  }
                },
                items: <String>['A', 'B', 'AB', 'O']
                    .map((String value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                ))
                    .toList(),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                onSave(selectedBloodType);
                Navigator.pop(context);
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveChanges() async {
    if (uid != null) {
      await FirebaseFirestore.instance.collection('user_profile').doc(uid).update({
        'name': name,
        'gender': gender,
        'dob': birthday,
        'blood_type': bloodType,
        'height': heightValue,
        'weight': weightValue,
        'avatar_url': avatarUrl,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('資料已更新')),
      );
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.of(context).pushReplacementNamed('/login');
  }

  Widget buildInfoRow(String label, String value, VoidCallback onEdit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('個人資訊'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundImage: _avatarImage != null
                    ? FileImage(_avatarImage!)
                    : (avatarUrl != null
                    ? NetworkImage(avatarUrl!)
                    : const AssetImage('assets/avatar.jpg')) as ImageProvider,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _changePhoto,
                child: const Text("更換照片"),
              ),
              const SizedBox(height: 20),
              buildInfoRow('姓名', name, () => editInfo('姓名', name, (value) => setState(() => name = value))),
              buildInfoRow('性別', gender, () => editInfo('性別', gender, (value) => setState(() => gender = value))),
              buildInfoRow('生日', birthday, () => editInfo('生日', birthday, (value) => setState(() => birthday = value))),
              buildInfoRow('年齡', '${calculateAge(birthday)} 歲', () {}), // 年齡直接算，不給編輯
              buildInfoRow('血型', bloodType, () => editBloodType(bloodType, (value) => setState(() => bloodType = value))),
              buildInfoRow('身高', '$heightValue cm', () => editNumericInfo('身高', heightValue, (value) => setState(() => heightValue = value))),
              buildInfoRow('體重', '$weightValue kg', () => editNumericInfo('體重', weightValue, (value) => setState(() => weightValue = value))),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveChanges,
                child: const Text('儲存變更'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: const PersonalInfoPage(),
    routes: {
      '/login': (context) => const LoginScreen(),
    },
  ));
}
