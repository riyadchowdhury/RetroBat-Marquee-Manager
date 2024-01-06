<h1>RetroBat-Marquee-Manager V2 - a Dynamic Marquees for RetroBat</h1>
<h2>Svg support, resizing, converting and dynamic scrapping</h2>
<img src="https://github.com/Nelfe80/RetroBat-Marquee-Manager/blob/master/dist/images/logo.png" style="width:60%">
<p>This project enables **dynamic display of marquees** on a secondary screen for RetroBat users on Windows 8+, utilizing custom scripts to manage the display based on user interactions.
</p>
<p>Thanks to Aynshe and Retrobat's community testers. </p>

<h2>Install</h2>
<p>
Important Setup Instructions for ESEvents and ESEventPush<br>
<b>Placement of Files</b>:<br>
Create a marquees folder : "C:\RetroBat\marquees"<br>
(download the project and go to the /dist folder and copy all files in "C:\RetroBat\marquees")<br>
Place events.ini and ESEvents.exe and StartRetrobatMarquees.bat in the "C:\RetroBat\marquees" directory.<br>
Place ESEventPush.exe in directories such as <br>
- "C:\RetroBat\emulationstation\.emulationstation\scripts\game-selected" >> update marquee when a game is selected<br>
- "C:\RetroBat\emulationstation\.emulationstation\scripts\system-selected" >> update marquee when a system is selected<br>
- "C:\RetroBat\emulationstation\.emulationstation\scripts\game-start" >> update marquee when a game start<br><br>
<b>Configuration File Setup</b>:<br>
Ensure that the ini file is correctly configured for proper operation of the executables.<br><br>
<b>Downloading and Installing Dependencies</b>:<br>
Download and install mpv and ImageMagick. These are essential for the functioning of the system.<br>
MPV to target screen and display images and videos : for mpv, visit their official website <a href="https://mpv.io">MPV's Website</a> and install it to the marquees directory, resulting in a path like "C:\RetroBat\marquees\mpv\mpv.exe".<br>
ImageMagick to convert (svg to png), resize and optimize images : for ImageMagick, visit <a href="https://imagemagick.org">ImageMagick's Website</a> and install it similarly in the marquees directory. This should result in a path like "C:\RetroBat\marquees\imagemagick\convert.exe".<br>
By following these instructions, you'll ensure that ESEvents.exe and ESEventPush.exe are correctly placed, and the necessary tools (mpv and ImageMagick) are installed and configured for optimal performance.
</p>

<h2>Configuring events.ini File</h2>
<p>
Configure events.ini to specify paths for marquees and other key settings like accepted formats, MPV path and ImageMagick path, etc. This file is crucial for the marquee system to function properly.
</p>

<h2>Scrapping usage</h2>
<p>
If you plan to use scraped marquees or incorporate your own custom marquee images into the system, please be aware of an issue in the scraping process. Both logos and marquee images are currently saved with the same suffix <b>-marquee</b> at the end of the file name. This can lead to confusion and potential file conflicts within the system.
</p>
<h3>How to Scrape Marquees from RetroBat (Workaround solution in Retrobat 5.3 stable version)</h3
<p>
To scrape marquees directly within RetroBat:
<ol>
<li>Access the scraping menu in RetroBat.</li>
<li>Choose to scrape from SCREENSCRAPER, HFSDB or ARCADEDB in the scraper options.</li>
<li>In the 'Logo Source' option, select 'Banner' to obtain real topper marquees.</li>
</ol>
This approach allows you to scrape specific marquee images that are more suited for use as toppers.
</p>
<p>
After scraping, you might encounter the situation where both marquees and logos are labeled with <b>-marquee</b>. To resolve this, use the script <b>RenameMarquees.bat</b>. This script will rename all marquee images, changing the <b>-marquee</b> suffix to <b>-marqueescrapped</b>. This renaming step is crucial for ensuring that marquee images are properly recognized and prioritized by the system. Moreover, it allows you to rescrape for the actual logos without overwriting the marquees you've just scraped. Once the script has been executed, and the marquee images are renamed to include <b>-marqueescrapped.png</b>, you can safely scrape again to obtain the true <b>-marquee</b> logos without any file conflicts.
</p>
<p>
It is important to note that SVG files may require additional processing time during their first use. However, once they are converted to PNG format, you will experience smoother navigation and quicker access to these images within the system.
</p>


<h3>StartRetroBat with StartRetrobatMarquees.bat to activate the dynamic marquee system and launch RetroBat.</h3> 
<h2>Notes</h2>
<p>
Ensure MPV and IMAGEMAGICK are installed in /RetroBat/marquees directory.
Organize your marquee images according to the structure defined in events.ini.
</p>
<p>
In cases where you encounter an error with <b>ESEventPush</b>, it's often due to EmulationStation sending empty strings for systems that don't contain any games or content. This can cause issues in the marquee update process, as the script expects valid data to operate correctly. It's important to be aware of this limitation when setting up and using the system.
</p>
<p>
However, this issue is known and is expected to be resolved in future updates of RetroBat and EmulationStation. Keeping your system up to date with the latest versions will ensure that you benefit from these improvements and experience fewer issues related 

