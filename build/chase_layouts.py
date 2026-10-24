"""Distinct course silhouettes with supported walking detours and faster jumps."""


def create_courses(arena, item, block, sign, prop, palette, resource):
    courses = item(arena, "Model", "ChaseCourses")
    definitions = ((2, "SHATTERED STEPS", 230, 0, 56, ()),
                   (3, "SERPENT SLALOM", -230, 0, 56, ()),
                   (4, "BROKEN CAUSEWAY", 0, -430, 18, ((-66, 7), (0, 7), (66, 7))),
                   (5, "RIFT GAUNTLET", 230, -430, 56, ((-52, 6), (52, 6))))
    for stage, title, ox, oz, width, gaps in definitions:
        section = item(courses, "Model", f"Course_{stage}")

        def part(name, size, pos, color=None, material=816, collide=True, **kwargs):
            return block(section, name, size, (ox+pos[0], pos[1], oz+pos[2]), color or palette["stone"], material, collide, **kwargs)

        start = -122
        for index, (end, next_start) in enumerate([(z-gap/2, z+gap/2) for z, gap in gaps]+[(122, 122)]):
            offset = (-12 if index % 2 == 0 else 12) if stage == 4 else 0
            part("CourseFloor", (width, 4, end-start), (offset, -2, (start+end)/2))
            part("FloatingStoneUnderside", (width*.8, 7, (end-start)*.85), (offset, -6, (start+end)/2), (50, 64, 83), 800, False, cls="WedgePart")
            for side in (-1, 1):
                part("CourseAccent", (.25, .15, end-start), (offset+side*(width/2-.2), .12, (start+end)/2), palette["mint"], 288, False)
            start = next_start
        for side in (-1, 1):
            part("CourseDeck", (56, 4, 48), (0, -2, side*146))
            # Low visible edging opens the view to scenery; the upper boundary
            # remains transparent so it does not create an opaque corridor.
            part("CourseRail", (2, 2, 344), (side*29.5, 0, 0), palette["edge"])
            part("CourseBoundary", (3, 24, 344), (side*29.5, 8, 0), palette["edge"], alpha=1)
            part("CourseBackWall", (62, 24, 3), (0, 8, side*173), palette["edge"], alpha=1)
            for x in (-24, 24):
                part("CourseGate", (3, 22, 3), (x, 11, side*146), palette["edge"])
                part("CourseAccent", (.5, 20, 3.2), (x, 11, side*146), palette["mint"], 288, False)
            part("CourseGateBeam", (51, 3, 3), (0, 22, side*146), palette["edge"])
        part("CourseFinish", (56, .2, 1.2), (0, .12, 122), palette["mint"], 288, False)
        sign(section, "FINISH!", (ox, 17.5, oz+146.4), (44, 4, .3))

        if stage == 2:
            for index, (z, height) in enumerate(((-70, 2.6), (0, 3.4), (74, 2.8))):
                x = -7 if index % 2 == 0 else 7
                part("CourseStep", (42, height, 5), (x, height/2, z), (67, 82, 103))
                part("JumpEdge", (42, .16, 5.1), (x, height+.1, z), palette["amber"], 288, False)
            part("BranchMonolith", (12, 7, 16), (0, 3.5, 34), palette["edge"])
            for side in (-1, 1):
                part("MonolithInset", (.18, 4, 12), (side*6.08, 4.2, 34), palette["violet"], 288, False)
            for index in range(3):
                top = 1.2*(index+1)
                part("ShortcutStep", (10, top, 4), (0, top/2, 10+index*4), (98, 112, 137))
                part("ShortcutGlow", (8, .1, .4), (0, top+.08, 11+index*4), palette["violet"], 288, False)
        elif stage == 3:
            for x, z, w, height in ((-9, -90, 38, 6), (9, 12, 38, 6)):
                part("SlalomWall", (w, height, 4), (x, height/2, z), palette["edge"])
                part("CourseAccent", (w, .2, 4.1), (x, height+.1, z), palette["violet"], 288, False)
            part("JumpHurdle", (24, 3.2, 7), (0, 1.6, -38), palette["edge"])
            part("BranchMonolith", (15, 6, 15), (0, 3, 70), (71, 83, 112), yaw=.785398)
            part("MonolithCrown", (15.5, .3, 15.5), (0, 6.2, 70), palette["violet"], 288, False, yaw=.785398)
            for side in (-1, 1):
                for z in (-60, 44):
                    part("RoutePlinth", (4, 1.3, 12), (side*23, .65, z), palette["edge"], collide=False)
        elif stage == 5:
            for index, z in enumerate((-94, -28, 28, 94)):
                side = -1 if index % 2 == 0 else 1
                part("SlalomWall", (38, 6.5, 4), (side*9, 3.25, z), palette["edge"])
                part("CourseAccent", (38, .2, 4.2), (side*9, 6.65, z), palette["violet"], 288, False)
            for z in (-12, 78):
                part("JumpHurdle", (22, 3.2, 3), (0, 1.6, z), palette["edge"])
                part("JumpEdge", (22, .16, 3.1), (0, 3.32, z), palette["amber"], 288, False)
            for index in range(3):
                top = 1.15*(index+1)
                part("ShortcutStep", (9, top, 4), (0, top/2, -46+index*4), (98, 112, 137))

        for index, (z, gap) in enumerate(gaps):
            offset = (-12 if index % 2 == 0 else 12) if stage == 4 else 0
            for edge in (-1, 1):
                x = offset if edge == -1 else (-offset if stage == 4 else 0)
                part("JumpEdge", (width, .15, .7), (x, .17, z+edge*(gap/2+.35)), palette["amber"], 288, False)
            # One broad detour alternates sides. There is no straight perimeter
            # lane; full-width junctions allow deliberate, supported crossings.
            side = (1 if index % 2 == 0 else -1) if stage == 4 else (1 if index == 0 else -1)
            part("CourseBypass", (12, 4, 28), (side*21, -2, z), (110, 130, 125))
            part("BypassEdge", (.4, .16, 28), (side*26.7, .16, z), palette["mint"], 288, False)
            for end in (-1, 1):
                part("CourseJunction", (56, 4, 8), (0, -2, z+end*10))

        for side in (-1, 1):
            for z in (-108, -42, 42, 108):
                part("RiftObelisk", (4, 18, 4), (side*34, 4, z), palette["edge"], collide=False)
                part("CourseAccent", (1, 14, 4.1), (side*34, 5, z), palette["violet"], 288, False)
            # Broken slab seams add readable scale without obstructing movement.
            for z in range(-112, 114, 16):
                if stage == 4:
                    continue
                part("PavingSeam", (23, .04, .12), (side*14, .025, z), (62, 78, 91), 816, False)
        pickups = {2: ((22, -46), (-22, 48)), 3: ((20, -58), (-20, 48)),
                   4: ((12, -40), (-12, 34)), 5: ((20, -72), (20, 42))}
        for index, (x, z) in enumerate(pickups[stage], 1):
            resource(section, f"Recharge_Course{stage}_{index}", (ox+x, 3, oz+z), "Stamina" if index == 1 else "Dash", item, block, prop)
    return courses
