# -*- coding: utf-8 -*-
import re

with open(r'D:\StayNest\landing\update.html', 'r', encoding='utf-8') as f:
    content = f.read()

replacement = """        <div class="max-w-2xl w-full bg-white p-10 rounded-3xl shadow-strong text-center border border-gray-100 mt-10">
          <img src="logo.svg" alt="StayNest Logo" class="h-24 w-auto mx-auto mb-6 object-contain drop-shadow-sm" />
          <div class="inline-block bg-primary/10 text-primary font-bold px-4 py-1 rounded-full text-sm mb-4">v1.0.2 Build 2</div>
          <h1 class="text-3xl font-extrabold text-dark mb-4 tracking-tight">Update Available</h1>
          <p class="text-graycustom mb-8 text-lg leading-relaxed">
            A new version of StayNest is ready! Please update to continue enjoying a secure and smooth experience.
          </p>
          <a 
            href="Staynest.apk" 
            class="inline-block px-8 py-4 bg-primary text-white font-bold rounded-2xl shadow-strong hover:scale-105 transition-all duration-300 w-full mb-10"
          >
            Download Latest Version
          </a>
          
          <div class="text-left border-t border-gray-100 pt-8">
            <h2 class="text-xl font-bold text-dark mb-6">What's New in v1.0.2 (Build 2)</h2>
            
            <div class="mb-6">
              <h3 class="font-bold text-dark flex items-center gap-2 mb-3">
                <span>✨</span> Localized Campus Property Taxonomy
              </h3>
              <ul class="list-disc pl-5 text-graycustom text-sm space-y-2">
                <li><span class="font-semibold text-primary">NEW:</span> Property features and amenities are now mapped to localized descriptors (e.g., "Own Token", "Tiles").</li>
                <li><span class="font-semibold text-primary">NEW:</span> Landlords can now add unique custom features to their properties.</li>
                <li><span class="font-semibold text-green-600">IMPROVED:</span> Property feeds intelligently extract and display the top 3 most popular highlights below the title.</li>
              </ul>
            </div>

            <div class="mb-6">
              <h3 class="font-bold text-dark flex items-center gap-2 mb-3">
                <span>🐛</span> Landlord Dashboard & Analytics
              </h3>
              <ul class="list-disc pl-5 text-graycustom text-sm space-y-2">
                <li><span class="font-semibold text-red-600">FIX:</span> Restored live engagement data. Fixed a critical bug where broken API endpoints forced the Landlord Dashboard to fall back to displaying "0" views.</li>
                <li><span class="font-semibold text-red-600">FIX:</span> Removed fake view generation logic to ensure complete data integrity.</li>
                <li><span class="font-semibold text-red-600">FIX:</span> Fully restored all broken network routes for property management, deletions, and booking statuses.</li>
              </ul>
            </div>

            <div class="mb-6">
              <h3 class="font-bold text-dark flex items-center gap-2 mb-3">
                <span>🔐</span> Authentication & UX
              </h3>
              <ul class="list-disc pl-5 text-graycustom text-sm space-y-2">
                <li><span class="font-semibold text-red-600">FIX:</span> Fixed a database bug where logging in with Google would silently destroy the user's previously uploaded profile avatar.</li>
                <li><span class="font-semibold text-red-600">FIX:</span> The loading spinner during Google Login now accurately awaits the background process instead of disappearing instantly.</li>
                <li><span class="font-semibold text-green-600">IMPROVED:</span> Failed Google sign-in attempts now properly trigger floating error SnackBars and UI feedback.</li>
              </ul>
            </div>

            <div>
              <h3 class="font-bold text-dark flex items-center gap-2 mb-3">
                <span>⚡</span> Performance & Notifications
              </h3>
              <ul class="list-disc pl-5 text-graycustom text-sm space-y-2">
                <li><span class="font-semibold text-red-600">FIX:</span> Fixed a double-caching bug where admin-approved properties would not immediately surface on the public home feed.</li>
                <li><span class="font-semibold text-primary">NEW:</span> Wired up the push/in-app notification service to actively alert landlords when their listings are Submitted, Approved, or Rejected.</li>
              </ul>
            </div>
          </div>
        </div>"""

content = re.sub(r'<div class="max-w-md w-full.*?</div>\s*</main>', replacement + '\n      </main>', content, flags=re.DOTALL)

with open(r'D:\StayNest\landing\update.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated landing/update.html")
