# -*- coding: utf-8 -*-
import re

with open(r'D:\StayNest\landing\update.html', 'r', encoding='utf-8') as f:
    content = f.read()

target = r'<div class="max-w-2xl w-full bg-white p-10 rounded-3xl shadow-strong text-center border border-gray-100 mt-10">.*?</div>\s*</main>'

replacement = """<div class="max-w-md w-full bg-white p-10 rounded-3xl shadow-strong text-center border border-gray-100 mt-10 mb-8">
          <img src="logo.svg" alt="StayNest Logo" class="h-24 w-auto mx-auto mb-6 object-contain drop-shadow-sm" />
          <h1 class="text-3xl font-extrabold text-dark mb-2 tracking-tight">Update Available</h1>
          <p class="text-sm font-bold" style="color: #3F37C9; margin-bottom: 1.5rem;">Version 1.0.2 (Build 2)</p>
          <p class="text-graycustom mb-8 text-lg leading-relaxed">
            A new version of StayNest is ready! Please update to continue enjoying a secure and smooth experience.
          </p>
          <a 
            href="Staynest.apk" 
            class="inline-block px-8 py-4 bg-primary text-white font-bold rounded-2xl shadow-strong hover:scale-105 transition-all duration-300 w-full"
          >
            Download Latest Version
          </a>
        </div>

        <div class="max-w-2xl w-full bg-white p-8 rounded-3xl shadow-strong border border-gray-100 mb-20 text-left">
          <h2 class="text-2xl font-extrabold text-dark mb-6 border-b border-gray-100 pb-4">Release Notes</h2>
          
          <div class="mb-6">
            <h3 class="font-bold text-dark text-lg mb-2" style="color: #3F37C9;">Localized Property Taxonomy</h3>
            <ul class="list-disc pl-5 text-graycustom space-y-1">
              <li><strong style="color: #333;">New:</strong> Amenities mapped to localized Kenyan descriptors (e.g. "Own Token", "Tiles").</li>
              <li><strong style="color: #333;">New:</strong> Landlords can add custom features during listing creation.</li>
              <li><strong style="color: #333;">Improved:</strong> Feeds now dynamically highlight the top 3 most popular features on property cards.</li>
            </ul>
          </div>

          <div class="mb-6">
            <h3 class="font-bold text-dark text-lg mb-2" style="color: #3F37C9;">Landlord Dashboard & Analytics</h3>
            <ul class="list-disc pl-5 text-graycustom space-y-1">
              <li><strong style="color: #333;">Fix:</strong> Restored live engagement data. Fixed a critical API bug that forced the dashboard to show 0 views.</li>
              <li><strong style="color: #333;">Fix:</strong> Removed fallback fake view logic to guarantee strict data integrity.</li>
              <li><strong style="color: #333;">Fix:</strong> Repaired all 6 broken network routes powering property management and booking statuses.</li>
            </ul>
          </div>

          <div class="mb-6">
            <h3 class="font-bold text-dark text-lg mb-2" style="color: #3F37C9;">Authentication & UX</h3>
            <ul class="list-disc pl-5 text-graycustom space-y-1">
              <li><strong style="color: #333;">Fix:</strong> Prevented Google Sign-In from silently overwriting manually uploaded user profile avatars.</li>
              <li><strong style="color: #333;">Fix:</strong> The loading spinner during Google Login now correctly awaits background processing.</li>
              <li><strong style="color: #333;">Improved:</strong> Failed sign-in attempts now reliably trigger red error SnackBars instead of failing silently.</li>
            </ul>
          </div>

          <div>
            <h3 class="font-bold text-dark text-lg mb-2" style="color: #3F37C9;">Performance & Notifications</h3>
            <ul class="list-disc pl-5 text-graycustom space-y-1">
              <li><strong style="color: #333;">Fix:</strong> Resolved a double-caching mechanism ensuring admin-approved properties surface on public feeds instantly.</li>
              <li><strong style="color: #333;">New:</strong> Active push/in-app notifications alert landlords when listings are Submitted, Approved, or Rejected.</li>
            </ul>
          </div>
        </div>
      </main>"""

content = re.sub(target, replacement, content, flags=re.DOTALL)

with open(r'D:\StayNest\landing\update.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated landing/update.html UI")
