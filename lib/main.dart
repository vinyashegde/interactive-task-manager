import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:particles_flutter/particles_flutter.dart'; // For floating particles effect

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Task {
  int? id;
  String name;
  String time;

  Task({this.id, required this.name, required this.time});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'time': time,
    };
  }

  static Task fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      name: map['name'],
      time: map['time'],
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'tasks.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          '''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            time TEXT
          )
          ''',
        );
      },
    );
  }

  Future<void> insertTask(Task task) async {
    final db = await database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Task>> getTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tasks');
    return List.generate(maps.length, (i) {
      return Task.fromMap(maps[i]);
    });
  }

  Future<void> deleteTask(int id) async {
    final db = await database;
    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<Task> _tasks = [];
  final _dbHelper = DatabaseHelper();
  String _currentTime = '';
  String _greetingMessage = '';
  String _userName = 'Alexey'; // Current user's name

  // For counting meetings, tasks, and habits
  int _meetings = 0;
  int _tasksCount = 0;
  int _habits = 1; // Static for now, can be updated later

  final Map<String, IconData> taskIcons = {
    'Design Crit': Icons.design_services, // Example icon for Design Crit
    'Team Meeting': Icons.group, // Icon for Team Meeting
    'One-on-One': Icons.person, // Icon for One-on-One
    'Finish designs': Icons.check_circle, // Icon for Finish Designs
    'Send email': Icons.email, // Icon for Send Email
    'Client call': Icons.phone, // Icon for Client Call
  };

  // Predefined task suggestions
  List<String> taskSuggestions = [
    'Design Crit',
    'Team Meeting',
    'One-on-One',
    'Finish designs',
    'Send email',
    'Client call',
  ];

  @override
  void initState() {
    super.initState();
    _fetchTasks();
    _startClock();
  }

  // Fetch tasks from the database
  Future<void> _fetchTasks() async {
    final tasks = await _dbHelper.getTasks();
    setState(() {
      _tasks = tasks;
      _updateTaskInfo();
    });
  }

  // Update task counts in the header
  void _updateTaskInfo() {
    setState(() {
      _tasksCount = _tasks.length; // Total tasks
      _meetings = _tasks
          .where((task) => task.name.toLowerCase().contains('meeting'))
          .length;
    });
  }

  // Function to add a new task
  Future<void> _addTask(String name, String time) async {
    final newTask = Task(name: name, time: time);
    await _dbHelper.insertTask(newTask);
    await _fetchTasks(); // Ensure the task list is updated
  }

  // Show task input dialog
  Future<void> _showAddTaskDialog() async {
    final _taskController = TextEditingController();
    final _timeController = TextEditingController();

    // Time picker logic
    Future<void> _selectTime(BuildContext context) async {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          _timeController.text = pickedTime.format(context);
        });
      }
    }

    return showDialog(
      context: this.context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Add New Task',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modern input fields
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[200],
                ),
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return taskSuggestions.where((String option) {
                      return option
                          .toLowerCase()
                          .contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    _taskController.text = selection;
                  },
                  fieldViewBuilder: (BuildContext context,
                      TextEditingController fieldTextEditingController,
                      FocusNode focusNode,
                      VoidCallback onFieldSubmitted) {
                    return TextField(
                      controller: fieldTextEditingController,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: 'Task Name',
                        border: InputBorder.none,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 20),
              GestureDetector(
                onTap: () => _selectTime(context),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey[200],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _timeController.text.isEmpty
                            ? 'Pick a Time'
                            : _timeController.text,
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      ),
                      Icon(Icons.access_time, color: Colors.black),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (_taskController.text.isNotEmpty &&
                    _timeController.text.isNotEmpty) {
                  _addTask(_taskController.text, _timeController.text);
                }
                Navigator.of(context).pop();
              },
              child: Text('Add Task'),
            ),
          ],
        );
      },
    );
  }

  // Delete a task
  Future<void> _deleteTask(int id) async {
    await _dbHelper.deleteTask(id);
    _fetchTasks();
  }

  Future<void> _showChangeNameDialog() async {
    final _nameController = TextEditingController(text: _userName);

    return showDialog(
      context: this.context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text('Change Your Name',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Enter your name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _userName = _nameController.text; // Update the name
                });
                Navigator.of(context).pop();
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Start real-time clock and update greeting message
  void _startClock() {
    Timer.periodic(Duration(seconds: 1), (Timer t) {
      final now = DateTime.now();
      String formattedTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      setState(() {
        _currentTime = formattedTime;
        _greetingMessage = _getGreetingMessage(
            now.hour); // Update greeting based on current hour
      });
    });
  }

  String _getGreetingMessage(int hour) {
    if (hour < 12) {
      return "Good Morning";
    } else if (hour < 18) {
      return "Good Afternoon";
    } else {
      return "Good Evening";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Add particle effect background
          CircularParticle(
            awayRadius: 80,
            numberOfParticles: 150,
            speedOfParticles: 1.5,
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            onTapAnimation: true,
            particleColor: Colors.white.withOpacity(0.3), // Set opacity to 30%
            awayAnimationDuration: Duration(milliseconds: 600),
            maxParticleSize: 3, // Smaller size for dot effect
            isRandSize: false, // Keep size consistent
            isRandomColor: false, // Use a single color
            awayAnimationCurve: Curves.easeInOutBack,
            enableHover: true,
            hoverColor: Colors.white,
            hoverRadius: 90,
            connectDots: false, // No connecting lines
          ),

          // Top section with time, greeting, and task info
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentTime,
                  style: TextStyle(
                      fontSize: 80,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap:
                      _showChangeNameDialog, // Call the dialog method when tapped
                  child: Text(
                    "${_greetingMessage}, $_userName",
                    style: TextStyle(fontSize: 22, color: Colors.white),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "You have $_meetings meetings, $_tasksCount tasks, and $_habits habit today.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Task list with draggable overlay
          DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 1.0,
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: ListView.builder(
                  controller: scrollController,
                  padding:
                      EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    final icon = taskIcons[task.name] ??
                        Icons.assignment; // Use default icon if not found

                    return AnimatedContainer(
                      duration: Duration(milliseconds: 300), // Animation effect
                      child: ListTile(
                        leading: Icon(icon, color: Colors.black), // Show icon
                        title: Text(
                          task.name,
                          style: TextStyle(color: Colors.black),
                        ),
                        subtitle: Text(task.time),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteTask(task.id!),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
