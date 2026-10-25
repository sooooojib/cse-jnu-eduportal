// Firebase Cloud Messaging Service Worker for Flutter Web
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Initialize Firebase in the service worker using web project credentials
firebase.initializeApp({
  apiKey: "AIzaSyB4jae-WiPeCGo6zYQ1b6IQDKTyHZYgZ6Q",
  appId: "1:685171866402:web:9c97e6831a32a9642d037b",
  messagingSenderId: "685171866402",
  projectId: "sajib-73b14",
  authDomain: "sajib-73b14.firebaseapp.com",
  storageBucket: "sajib-73b14.firebasestorage.app",
  measurementId: "G-87X20PFQF7"
});

// Retrieve an instance of Firebase Messaging
const messaging = firebase.messaging();

// Background message handler
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);
  const notificationTitle = payload.notification ? payload.notification.title : 'JnU CSE EduPortal';
  const notificationOptions = {
    body: payload.notification ? payload.notification.body : '',
    icon: '/favicon.png',
    data: payload.data
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
