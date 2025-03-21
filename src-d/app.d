module app;

import libwasm;

import navbar;
import dock;

nothrow:
@safe:

mixin Spa!App;
/***
  - Login/Register/Reset Password screen (Sign in with Apple / Sign in with Google)
  - Workspace with project folders in grid
  - List of photos in a project with metadata (Size, Date modified, caption)
    - Checkmark to select the photos
    - Delete icon
    - Add photo button
    - Next button
  - Vertical list with selected photos large previews and size, clickable to edit, reorder button
  - Tap-ordering view (numbers increment each tap to define ordering?)
    - Clickable number on photos
    - Number field with ordering and up/down arrows
  - Photo edit screen with bottom horizontal toolbar (Rotate, Crop, Filter, Motion, Transition, Save)
  - Preview screen with play button, pause button, and timeline scrubber
  - Export screen with options (Quality, Resolution, Format, Filesize)
  - Share screen with options (Social media, Email, Copy link)
  - Settings screen with options (Account, Notifications, Privacy, Help)
  - Render queue screen with progress bars and cancel button (for each transition+motion slide)
    - Photos have b/w->color progress% over the icon

*/


/*
<div class="navbar bg-base-100 shadow-sm">
  <div class="navbar-start">
    <div class="dropdown">
      <div tabindex="0" role="button" class="btn btn-ghost lg:hidden">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"> <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h8m-8 6h16" /> </svg>
      </div>
      <ul
        tabindex="0"
        class="menu menu-sm dropdown-content bg-base-100 rounded-box z-1 mt-3 w-52 p-2 shadow">
        <li><a>Item 1</a></li>
        <li>
          <a>Parent</a>
          <ul class="p-2">
            <li><a>Submenu 1</a></li>
            <li><a>Submenu 2</a></li>
          </ul>
        </li>
        <li><a>Item 3</a></li>
      </ul>
    </div>
    <a class="btn btn-ghost text-xl">daisyUI</a>
  </div>
  <div class="navbar-center hidden lg:flex">
    <ul class="menu menu-horizontal px-1">
      <li><a>Item 1</a></li>
      <li>
        <details>
          <summary>Parent</summary>
          <ul class="p-2">
            <li><a>Submenu 1</a></li>
            <li><a>Submenu 2</a></li>
          </ul>
        </details>
      </li>
      <li><a>Item 3</a></li>
    </ul>
  </div>
  <div class="navbar-end">
    <a class="btn">Button</a>
  </div>
</div>
*/



extern (C) void logObjects();

struct Main { nothrow:
  @child Page page;

  struct Page {
    @prop!"innerHTML" string innerHTML = `<div class="container mx-auto p-4 max-h-fit"><h1 class="text-4xl font-bold">Hello World!</h1></div>`;

    //
    mixin NodeDef!"div";
  }
  //
  @style!"bg-base-100 shadow-sm" mixin NodeDef!"section";
}

struct App
{
nothrow:
  @child NavBar navbar;
  @child Main content;
  @child Dock dock;

  ManagedPool m_pool;

  void construct()
  {
    m_pool = ManagedPool(64 * 1024);
    console.log("Construct called");
  }

  //  
  mixin NodeDef!"div";
}
