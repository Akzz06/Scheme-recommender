import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dobController = TextEditingController();

  String? _selectedState;
  String? _selectedGender;
  String? _selectedCaste;
  String? _selectedOccupation;
  DateTime? _selectedDate;

  // **USE THE FULL LIST OF STATES HERE**
  final List<String> _states = [
    'Andaman and Nicobar Islands', 'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar',
    'Chandigarh', 'Chhattisgarh', 'Dadra and Nagar Haveli and Daman and Diu', 'Delhi', 'Goa',
    'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jammu and Kashmir', 'Jharkhand', 'Karnataka',
    'Kerala', 'Ladakh', 'Lakshadweep', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
    'Mizoram', 'Nagaland', 'Odisha', 'Puducherry', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
    'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal'
  ];
  final List<String> _genders = ['Male', 'Female', 'Transgender'];
  final List<String> _castes = ['General', 'OBC', 'SC', 'ST'];
  final List<String> _occupations = [
    'Farmer', 'Student', 'Ex Servicemen', 'Journalist', 'Women', 'Entrepreneur',
    'Unorganized Worker', 'Person With Disability',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedState = prefs.getString('profile_state');
      _selectedGender = prefs.getString('profile_gender');
      _selectedCaste = prefs.getString('profile_caste');
      _selectedOccupation = prefs.getString('profile_occupation');
      String? dobString = prefs.getString('profile_dob');
      if (dobString != null) {
        try {
          _selectedDate = DateTime.parse(dobString);
           _dobController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
        } catch(e) {
          print("Error parsing saved date: $e");
           // Clear invalid date
          prefs.remove('profile_dob');
        }
      }
    });
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('profile_state', _selectedState!);
      await prefs.setString('profile_gender', _selectedGender!);
      await prefs.setString('profile_caste', _selectedCaste!);
      await prefs.setString('profile_occupation', _selectedOccupation!);
      await prefs.setString('profile_dob', _selectedDate!.toIso8601String());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile Saved! Applying recommendations...'), duration: Duration(seconds: 2)),
        );
        Navigator.of(context).pop(true); // Return 'true' to signal refresh
      }
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all fields'), duration: Duration(seconds: 2)),
        );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(DateTime.now().year - 30), // Default to 30 years ago
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Your Profile'),
        backgroundColor: Colors.green[50], // Light green AppBar
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               const Text(
                  "Enter your details to find relevant schemes:",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
               const SizedBox(height: 24),
              TextFormField(
                controller: _dobController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date of Birth',
                  border: const OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today, color: Colors.green[700]),
                ),
                onTap: () => _selectDate(context),
                validator: (value) => value == null || value.isEmpty ? 'Please select date of birth' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                items: _genders.map((gender) => DropdownMenuItem(value: gender, child: Text(gender))).toList(),
                onChanged: (value) => setState(() => _selectedGender = value),
                validator: (value) => value == null ? 'Please select gender' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCaste,
                decoration: const InputDecoration(labelText: 'Caste', border: OutlineInputBorder()),
                items: _castes.map((caste) => DropdownMenuItem(value: caste, child: Text(caste))).toList(),
                onChanged: (value) => setState(() => _selectedCaste = value),
                validator: (value) => value == null ? 'Please select caste' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedState,
                 isExpanded: true,
                decoration: const InputDecoration(labelText: 'State', border: OutlineInputBorder()),
                items: _states.map((state) => DropdownMenuItem(value: state, child: Text(state, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (value) => setState(() => _selectedState = value),
                validator: (value) => value == null ? 'Please select state' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedOccupation,
                 isExpanded: true,
                decoration: const InputDecoration(labelText: 'Occupation / Category', border: OutlineInputBorder()),
                items: _occupations.map((occupation) => DropdownMenuItem(value: occupation, child: Text(occupation, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (value) => setState(() => _selectedOccupation = value),
                 validator: (value) => value == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.save_alt_rounded),
                label: const Text('Save and Find Schemes', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(vertical: 15),
                  // backgroundColor: Colors.green, // Theme color
                  // foregroundColor: Colors.white,
                  ),
                onPressed: _saveProfile,
              )
            ],
          ),
        ),
      ),
    );
  }
}