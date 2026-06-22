class AppLocalizations {
  final String locale;
  AppLocalizations(this.locale);

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_title': 'IRIS',
      'app_subtitle': 'AI Powered EYE Screening',
      'tagline': 'Early Detection,\nBetter Vision',
      'get_started': 'Get Started',
      'login': 'Login',
      'already_have_account': 'Already have an account?',
      'dont_have_account': 'Don\'t have an account?',
      'sign_up': 'Sign Up',
      'welcome_back': 'Welcome Back!',
      'login_to_continue': 'Login to continue',
      'email': 'Email',
      'password': 'Password',
      'full_name': 'Full Name',
      'confirm_password': 'Confirm Password',
      'create_account': 'Create Account',
      'signup_to_continue': 'Sign up to continue',
      'reset_password': 'Reset Password',
      'enter_email_reset': 'Enter your email to reset your password',
      'send_reset_email': 'Send Reset Email',
      'forgot_password': 'Forgot Password?',
      'or_continue_with': 'or continue with',

      // Greeting
      'hello': 'Hello',
      'hello_user': 'Hello, User \uD83D\uDC4B',
      'take_care_eyes': 'Take care of your eyes!',

      // Dashboard
      'overall_risk_status': 'Overall Risk Status',
      'moderate_risk': 'Moderate Risk',
      'low_risk': 'Low Risk',
      'high_risk': 'High Risk',
      'no_data': 'No Data',
      'total_scans': 'Total Scans',
      'normal': 'Normal',
      'glaucoma': 'Glaucoma',
      'last_scan': 'Last Scan',
      'view_all': 'View All',
      'risk': 'Risk',
      'loading_dashboard': 'Loading your dashboard...',
      'error_loading_dashboard': 'Unable to load dashboard data',
      'no_scans_yet': 'No Scans Yet',
      'start_first_scan': 'Start your first eye scan to see your results here',

      // Navigation
      'home': 'Home',
      'scan': 'Scan',
      'history': 'History',
      'reports': 'Reports',
      'profile': 'Profile',
      'logout': 'Logout',

      // Scan
      'start_new_scan': 'Start New Scan',
      'capture_upload_desc': 'Capture or upload a fundus image\nfor analysis',
      'capture_image': 'Capture Image',
      'upload_image': 'Upload Image',
      'tips_for_best_result': 'Tips for best result',
      'tip_1': 'Ensure good lighting',
      'tip_2': 'Keep the lens steady',
      'tip_3': 'Align the eye properly',
      'analyze_image': 'Analyze Image',
      'reselect_image': 'Reselect Image',
      'permission_denied_enable_in_settings': 'Permission denied. Please enable it in device settings.',

      // Analysis
      'analyzing_image': 'Analyzing Image',
      'please_wait': 'Please wait...',
      'analyzing_desc': 'Our AI is analyzing your\nfundus image',
      'step_1': 'Image Enhancement',
      'step_2': 'Optic Disc Detection',
      'step_3': 'CDR Calculation',
      'step_4': 'Risk Prediction',

      // Results
      'analysis_results': 'Analysis Results',
      'glaucoma_suspected': 'Glaucoma Suspected',
      'risk_score': 'Risk Score',
      'key_parameters': 'Key Parameters',
      'cdr': 'Cup-to-Disc Ratio (CDR)',
      'optic_disc_asymmetry': 'Optic Disc Asymmetry',
      'neuroretinal_rim': 'Neuroretinal Rim',
      'blood_vessel_pattern': 'Blood Vessel Pattern',
      'abnormal': 'Abnormal',
      'thinning': 'Thinning',

      // Report
      'your_report': 'Your Report',
      'patient_name': 'Patient Name',
      'age_gender': 'Age / Gender',
      'scan_date': 'Scan Date',
      'result': 'Result',
      'recommendation': 'Recommendation',
      'recommendation_desc': 'Please consult an ophthalmologist\nfor further evaluation.',
      'download_pdf': 'Download PDF',
      'share_report': 'Share Report',
      'normal_recommendation_desc': 'Your screening results appear normal.\nContinue routine eye screening annually.',
      'report_disclaimer': 'This is an AI-generated screening result and should not be considered a medical diagnosis. Please consult a qualified medical professional for definitive diagnosis and treatment.',
      'no_scan_data': 'No Scan Data Available',
      'scan_first_to_generate': 'Please complete a scan first to generate your report and PDF.',

      // Welcome
      'ai_powered_analysis': 'AI Powered\nAnalysis',
      'accurate_risk': 'Accurate\nRisk Prediction',
      'secure_data': 'Secure Data\nProtection',
      'fast_easy': 'Fast & Easy\nScreening',

      // History
      'scan_history': 'Scan History',
      'error_loading_history': 'Error loading scan history',
      'retry': 'Retry',
      'no_scan_history': 'No Scan History',
      'start_scanning_to_build_history': 'Start scanning to build your history',
      'recent_scans': 'Recent Scans',
      'scan_statistics': 'Scan Statistics',
      'avg_confidence': 'Average Confidence',
      'confidence_score': 'Confidence Score',

      // PDF
      'generating_pdf': 'Generating...',
      'pdf_generated': 'PDF Generated!',
      'pdf_generation_failed': 'PDF generation failed',
      'sharing_report': 'Sharing...',
      'share_failed': 'Share failed',

      // Profile
      'not_authenticated': 'Not Authenticated',
      'account_information': 'Account Information',
      'account_actions': 'Account Actions',
      'edit_profile': 'Edit Profile',
      'change_password': 'Change Password',
      'delete_account': 'Delete Account',
      'joined': 'Joined',
      'verified': 'Verified',
      'yes': 'Yes',
      'no': 'No',
      'logging_out': 'Logging out...',
      'logout_confirm_title': 'Logout',
      'logout_confirm_message': 'Are you sure you want to logout?',
      'cancel': 'Cancel',
      'save': 'Save',

      // Profile — Edit
      'name_required': 'Name is required',
      'profile_updated_success': 'Profile updated successfully',

      // Profile — Change Password
      'current_password': 'Current Password',
      'new_password': 'New Password',
      'confirm_new_password': 'Confirm New Password',
      'current_password_required': 'Current password is required',
      'new_password_required': 'New password is required',
      'confirm_password_required': 'Please confirm your password',
      'password_min_length': 'Password must be at least 6 characters',
      'passwords_do_not_match': 'Passwords do not match',
      'password_changed_success': 'Password changed successfully',
      'password_required': 'Password is required',

      // Profile — Delete Account
      'delete_account_warning': 'This action is permanent and cannot be undone. All your scan history, reports, and account data will be permanently deleted.',
      'delete_account_confirm': 'Yes, Delete My Account',
      'enter_password_to_confirm': 'Enter your password to confirm',
      'delete_permanently': 'Delete Permanently',
      'account_deleted_success': 'Account deleted successfully',

      // Misc & Errors
      'error_saving_scan': 'Error saving scan:',
      'unexpected_error_pdf': 'An unexpected error occurred during PDF generation.',
      'unexpected_error_share': 'An unexpected error occurred while sharing.',
      'could_not_open_file': 'Could not open file:',
      'open': 'OPEN',

      // PDF Content
      'eye_screening_report': 'Eye Screening Report',
      'ai_powered_glaucoma_screening': 'AI-Powered Glaucoma Screening',
      'confidential': 'Confidential',
      'patient_information': 'Patient Information',
      'retinal_fundus_image': 'Retinal Fundus Image',
      'scan_results': 'Scan Results',
      'predicted_class': 'Predicted Class',
      'glaucoma_screening_platform': 'IRIS - AI Eye Screening Platform',
    },
    'ta': {
      'app_title': 'ஐரிஸ் (IRIS)',
      'app_subtitle': 'AI மூலம் கண் பரிசோதனை',
      'tagline': 'ஆரம்பகால கண்டறிதல்,\nசிறந்த பார்வை',
      'get_started': 'தொடங்கவும்',
      'login': 'உள்நுழைக',
      'already_have_account': 'ஏற்கனவே கணக்கு உள்ளதா?',
      'dont_have_account': 'கணக்கு இல்லையா?',
      'sign_up': 'பதிவு செய்க',
      'welcome_back': 'மீண்டும் வருக!',
      'login_to_continue': 'தொடர உள்நுழைக',
      'email': 'மின்னஞ்சல்',
      'password': 'கடவுச்சொல்',
      'full_name': 'முழு பெயர்',
      'confirm_password': 'கடவுச்சொல்லை உறுதிப்படுத்தவும்',
      'create_account': 'கணக்கு உருவாக்கு',
      'signup_to_continue': 'பதிவு செய்க தொடர',
      'reset_password': 'கடவுச்சொல்லை மீட்டமை',
      'enter_email_reset': 'கடவுச்சொல்லை மீட்டமை மின்னஞ்சல் உள்ளிடவும்',
      'send_reset_email': 'மீட்டமை மின்னஞ்சல் அனுப்பு',
      'forgot_password': 'கடவுச்சொல் மறந்துவிட்டதா?',
      'or_continue_with': 'அல்லது இதன் மூலம் தொடரவும்',

      // Greeting
      'hello': 'வணக்கம்',
      'hello_user': 'வணக்கம், பயனர் \uD83D\uDC4B',
      'take_care_eyes': 'உங்கள் கண்களை கவனித்துக் கொள்ளுங்கள்!',

      // Dashboard
      'overall_risk_status': 'ஒட்டுமொத்த ஆபத்து நிலை',
      'moderate_risk': 'மிதமான ஆபத்து',
      'low_risk': 'குறைந்த ஆபத்து',
      'high_risk': 'அதிக ஆபத்து',
      'no_data': 'தரவு இல்லை',
      'total_scans': 'மொத்த ஸ்கேன்கள்',
      'normal': 'சாதாரணம்',
      'glaucoma': 'கிளாக்கோமா',
      'last_scan': 'கடைசி ஸ்கேன்',
      'view_all': 'அனைத்தையும் காண்',
      'risk': 'ஆபத்து',
      'loading_dashboard': 'டாஷ்போர்டு ஏற்றுகிறது...',
      'error_loading_dashboard': 'டாஷ்போர்டு தரவை ஏற்ற முடியவில்லை',
      'no_scans_yet': 'ஸ்கேன்கள் இல்லை',
      'start_first_scan': 'உங்கள் முடிவுகளை இங்கே காண முதல் கண் ஸ்கேன் தொடங்கவும்',

      // Navigation
      'home': 'முகப்பு',
      'scan': 'ஸ்கேன்',
      'history': 'வரலாறு',
      'reports': 'அறிக்கைகள்',
      'profile': 'சுயவிவரம்',
      'logout': 'வெளியேறு',

      // Scan
      'start_new_scan': 'புதிய ஸ்கேன் தொடங்கு',
      'capture_upload_desc': 'பகுப்பாய்வுக்காக ஃபண்டஸ்\nபடத்தைப் பிடிக்கவும் அல்லது பதிவேற்றவும்',
      'capture_image': 'படம் பிடி',
      'upload_image': 'பதிவேற்று',
      'tips_for_best_result': 'சிறந்த முடிவுக்கான குறிப்புகள்',
      'tip_1': 'நல்ல வெளிச்சத்தை உறுதி செய்யவும்',
      'tip_2': 'லென்ஸை நிலையாக வைக்கவும்',
      'tip_3': 'கண்ணை சரியாக சீரமைக்கவும்',
      'analyze_image': 'படத்தை பகுப்பாய்வு செய்',
      'reselect_image': 'படத்தை மீண்டும் தேர்வுசெய்',
      'permission_denied_enable_in_settings': 'அனுமதி மறுக்கப்பட்டது. சாதன அமைப்புகளில் இயக்கவும்.',

      // Analysis
      'analyzing_image': 'படம் பகுப்பாய்வு செய்யப்படுகிறது',
      'please_wait': 'காத்திருக்கவும்...',
      'analyzing_desc': 'எங்கள் AI உங்கள் ஃபண்டஸ்\nபடத்தை பகுப்பாய்வு செய்கிறது',
      'step_1': 'படம் மேம்பாடு',
      'step_2': 'ஆப்டிக் டிஸ்க் கண்டறிதல்',
      'step_3': 'CDR கணக்கீடு',
      'step_4': 'ஆபத்து கணிப்பு',

      // Results
      'analysis_results': 'பகுப்பாய்வு முடிவுகள்',
      'glaucoma_suspected': 'கிளாக்கோமா சந்தேகம்',
      'risk_score': 'ஆபத்து மதிப்பெண்',
      'key_parameters': 'முக்கிய அளவுருக்கள்',
      'cdr': 'கப்-டு-டிஸ்க் விகிதம் (CDR)',
      'optic_disc_asymmetry': 'ஆப்டிக் டிஸ்க் சமச்சீரற்ற தன்மை',
      'neuroretinal_rim': 'நியூரோரெட்டினல் விளிம்பு',
      'blood_vessel_pattern': 'ரத்தக்குழாய் அமைப்பு',
      'abnormal': 'அசாதாரணம்',
      'thinning': 'மெலிதல்',

      // Report
      'your_report': 'உங்கள் அறிக்கை',
      'patient_name': 'நோயாளி பெயர்',
      'age_gender': 'வயது / பாலினம்',
      'scan_date': 'ஸ்கேன் தேதி',
      'result': 'முடிவு',
      'recommendation': 'பரிந்துரை',
      'recommendation_desc': 'மேலும் மதிப்பீட்டிற்கு தயவுசெய்து\nகண் மருத்துவரை அணுகவும்.',
      'download_pdf': 'PDF பதிவிறக்கு',
      'share_report': 'அறிக்கையை பகிர்',
      'normal_recommendation_desc': 'உங்கள் பரிசோதனை முடிவுகள் சாதாரணமாக உள்ளன.\nஆண்டுதோறும் வழக்கமான கண் பரிசோதனையை தொடரவும்.',
      'report_disclaimer': 'இது AI-உருவாக்கிய பரிசோதனை முடிவு மற்றும் மருத்துவ நோயறிதலாக கருதப்படக்கூடாது. உறுதியான நோயறிதல் மற்றும் சிகிச்சைக்கு தகுதிவாய்ந்த மருத்துவ நிபுணரை அணுகவும்.',
      'no_scan_data': 'ஸ்கேன் தரவு இல்லை',
      'scan_first_to_generate': 'உங்கள் அறிக்கை மற்றும் PDF ஐ உருவாக்க முதலில் ஸ்கேன் செய்யவும்.',

      // Welcome
      'ai_powered_analysis': 'AI பகுப்பாய்வு',
      'accurate_risk': 'துல்லியமான\nஆபத்து கணிப்பு',
      'secure_data': 'பாதுகாப்பான\nதரவு பாதுகாப்பு',
      'fast_easy': 'வேகமான &\nஎளிதான ஸ்கிரீனிங்',

      // History
      'scan_history': 'ஸ்கேன் வரலாறு',
      'error_loading_history': 'ஸ்கேன் வரலாறு லோட் செய்வதில் பிழை',
      'retry': 'மீண்டும் முயற்சி செய்க',
      'no_scan_history': 'ஸ்கேன் வரலாறு இல்லை',
      'start_scanning_to_build_history': 'உங்கள் வரலாற்றை உருவாக்க ஸ்கேனிங் தொடங்கவும்',
      'recent_scans': 'சமீபத்திய ஸ்கேன்கள்',
      'scan_statistics': 'ஸ்கேன் புள்ளிவிவரம்',
      'avg_confidence': 'சராசரி நம்பிக்கை',
      'confidence_score': 'நம்பிக்கை மதிப்பெண்',

      // PDF
      'generating_pdf': 'உருவாக்குகிறது...',
      'pdf_generated': 'PDF உருவாக்கப்பட்டது!',
      'pdf_generation_failed': 'PDF உருவாக்கம் தோல்வி',
      'sharing_report': 'பகிர்கிறது...',
      'share_failed': 'பகிர்வு தோல்வி',

      // Profile
      'not_authenticated': 'உள்நுழையவில்லை',
      'account_information': 'கணக்கு தகவல்',
      'account_actions': 'கணக்கு செயல்கள்',
      'edit_profile': 'சுயவிவரத்தைத் திருத்து',
      'change_password': 'கடவுச்சொல்லை மாற்று',
      'delete_account': 'கணக்கை நீக்கு',
      'joined': 'சேர்ந்தது',
      'verified': 'சரிபார்க்கப்பட்டது',
      'yes': 'ஆம்',
      'no': 'இல்லை',
      'logging_out': 'வெளியேறுகிறது...',
      'logout_confirm_title': 'வெளியேறு',
      'logout_confirm_message': 'நீங்கள் நிச்சயமாக வெளியேற விரும்புகிறீர்களா?',
      'cancel': 'ரத்துசெய்',
      'save': 'சேமி',

      // Profile — Edit
      'name_required': 'பெயர் தேவை',
      'profile_updated_success': 'சுயவிவரம் வெற்றிகரமாக புதுப்பிக்கப்பட்டது',

      // Profile — Change Password
      'current_password': 'தற்போதைய கடவுச்சொல்',
      'new_password': 'புதிய கடவுச்சொல்',
      'confirm_new_password': 'புதிய கடவுச்சொல்லை உறுதிப்படுத்தவும்',
      'current_password_required': 'தற்போதைய கடவுச்சொல் தேவை',
      'new_password_required': 'புதிய கடவுச்சொல் தேவை',
      'confirm_password_required': 'கடவுச்சொல்லை உறுதிப்படுத்தவும்',
      'password_min_length': 'கடவுச்சொல் குறைந்தது 6 எழுத்துகள் இருக்க வேண்டும்',
      'passwords_do_not_match': 'கடவுச்சொற்கள் பொருந்தவில்லை',
      'password_changed_success': 'கடவுச்சொல் வெற்றிகரமாக மாற்றப்பட்டது',
      'password_required': 'கடவுச்சொல் தேவை',

      // Profile — Delete Account
      'delete_account_warning': 'இந்த செயல் நிரந்தரமானது மற்றும் மாற்ற முடியாது. உங்கள் அனைத்து ஸ்கேன் வரலாறு, அறிக்கைகள் மற்றும் கணக்கு தரவு நிரந்தரமாக நீக்கப்படும்.',
      'delete_account_confirm': 'ஆம், எனது கணக்கை நீக்கு',
      'enter_password_to_confirm': 'உறுதிப்படுத்த கடவுச்சொல் உள்ளிடவும்',
      'delete_permanently': 'நிரந்தரமாக நீக்கு',
      'account_deleted_success': 'கணக்கு வெற்றிகரமாக நீக்கப்பட்டது',

      // Misc & Errors
      'error_saving_scan': 'ஸ்கேனை சேமிப்பதில் பிழை:',
      'unexpected_error_pdf': 'PDF உருவாக்கும்போது எதிர்பாராத பிழை ஏற்பட்டது.',
      'unexpected_error_share': 'பகிரும்போது எதிர்பாராத பிழை ஏற்பட்டது.',
      'could_not_open_file': 'கோப்பைத் திறக்க முடியவில்லை:',
      'open': 'திற',

      // PDF Content
      'eye_screening_report': 'கண் பரிசோதனை அறிக்கை',
      'ai_powered_glaucoma_screening': 'AI-ஆதரவு கிளாக்கோமா பரிசோதனை',
      'confidential': 'ரகசியம்',
      'patient_information': 'நோயாளி தகவல்',
      'retinal_fundus_image': 'ரெட்டினல் ஃபண்டஸ் படம்',
      'scan_results': 'ஸ்கேன் முடிவுகள்',
      'predicted_class': 'கணிக்கப்பட்ட வகுப்பு',
      'glaucoma_screening_platform': 'ஐரிஸ் (IRIS) - AI கண் பரிசோதனை தளம்',
    }
  };

  String get(String key) {
    return _localizedValues[locale]?[key] ?? key;
  }
}

// Usage: 'app_title'.tr(ref.watch(localeProvider).languageCode)
extension LocalizationExtension on String {
  String tr(String locale) {
    return AppLocalizations(locale).get(this);
  }
}
