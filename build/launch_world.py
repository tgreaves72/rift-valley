"""Optional movement lesson on a separate island, with no race geometry changes."""
from activity_icons import small_tag

def launch_world(lobby, item, block, prop):
    mint, violet, gold = (108,255,204), (190,139,255), (255,221,137)
    lane=item(lobby,"Model","TutorialLane")
    block(lane,"LessonFloor",(32,5,132),(-210,25.5,346),(43,40,67),816)
    for x in (-226, -194):
        block(lane,"LessonBoundary",(1,35,132),(x,44,346),(72,56,112),816,alpha=1)
        block(lane,"LessonRail",(.6,2,132),(x,29,346),violet,288,False)
    for z in (280,412): block(lane,"LessonEnd",(32,35,1),(-210,44,z),(72,56,112),816,alpha=1)
    block(lane,"JumpHurdle",(30,2.5,2),(-210,29.25,307),violet,816)
    for index,z in enumerate((321,354,397),1):
        pad=block(lane,f"LessonTarget{index}",(16,.25,7),(-210,28.15,z),(mint,violet,gold)[index-1],288,False)
        small_tag(pad,pad,("Jump!","Sprint!","Dash!")[index-1],(0,5,0),(mint,violet,gold)[index-1],item,prop)
    for z in range(287,408,6):
        for x in (-222,-198): block(lane,"LessonGuide",(.3,.1,2),(x,28.15,z),mint,288,False)
    for z,color in ((321,mint),(354,violet),(397,gold)):
        for x in (-220,-200): block(lane,"TargetArch",(.5,9,.5),(x,32.5,z),color,288,False)
        block(lane,"TargetArch",(20,.5,.5),(-210,37,z),color,288,False)
    plate=block(lobby,"TutorialPlate",(10,.5,10),(-45,28.35,290),mint,288)
    for x in (-48,-42):
        block(plate,"LearnArrow",(.7,2,.7),(x,35,290),mint,288,False)
        block(plate,"LearnArrowTip",(2.3,2.3,.5),(x,36.7,290),mint,288,False,cls="WedgePart")
    small_tag(plate,plate,"Learn to Run",(0,10,0),mint,item,prop)
